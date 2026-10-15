-- Feasibility checks for the candidate investigations (docs/investigations.md).
-- Run after etl/load.sh:  psql "$DATABASE_URL" -X -P pager=off -f analysis/investigation_checks.sql > analysis/results.txt
--
-- Definitions used throughout:
--   applications  = action_taken 1-5 (excludes 6 purchased loans and 7-8 preapproval-only requests)
--   denial rate   = denied (3) / (originated 1 + approved not accepted 2 + denied 3)   [CFPB convention]
--   "similar loan" for pricing = 2024, home purchase, conventional, first lien, owner-occupied,
--                                30-year term, originated, $400k-$500k
SET search_path TO mme;
-- Written for the first-load schema (lei and county_fips on application). Since D10 the table
-- stores lender_id and county_id; this temporary view puts the old columns back so the checks
-- run unchanged. App queries should join lender / county on the ids directly.
CREATE TEMP VIEW application AS
SELECT a.*, l.lei, c.county_fips
FROM mme.application a JOIN mme.lender l USING (lender_id) JOIN mme.county c USING (county_id);
\timing off
\pset footer off

\echo '=================================================================='
\echo 'A. DATA PROFILE'
\echo '=================================================================='
\echo '-- A1 rows by year and outcome'
SELECT a.year, c.label AS outcome, count(*) AS rows,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY a.year), 1) AS pct_of_year
FROM application a JOIN action_taken_code c ON c.code = a.action_taken
GROUP BY a.year, a.action_taken, c.label ORDER BY a.year, a.action_taken;

\echo '-- A2 row totals under different scope choices (1M-row safety, decision D3)'
SELECT count(*) AS all_rows,
       count(*) FILTER (WHERE action_taken <> 6) AS excl_purchased,
       count(*) FILTER (WHERE action_taken BETWEEN 1 AND 5) AS applications_only,
       count(*) FILTER (WHERE year >= 2022) AS years_2022_2024_all,
       count(*) FILTER (WHERE year >= 2022 AND action_taken <> 6) AS years_2022_2024_excl_purchased
FROM application;

\echo '-- A3 loan purpose mix by year (applications)'
SELECT a.year, p.label AS purpose, count(*) AS applications,
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY a.year), 1) AS pct
FROM application a JOIN loan_purpose_code p ON p.code = a.loan_purpose
WHERE a.action_taken BETWEEN 1 AND 5
GROUP BY a.year, p.code, p.label ORDER BY a.year, p.code;

\echo '-- A4 pricing fields filled in, originated loans (Investigation 1 needs these)'
SELECT year, count(*) AS originations,
       round(100.0 * count(interest_rate) / count(*), 1) AS pct_with_rate,
       round(100.0 * count(total_loan_costs) / count(*), 1) AS pct_with_total_costs,
       round(100.0 * count(discount_points) / count(*), 1) AS pct_with_points,
       round(100.0 * count(dti_bucket) / count(*), 1) AS pct_with_dti
FROM application WHERE action_taken = 1
GROUP BY year ORDER BY year;

\echo '-- A5 average bytes per application row (size budget)'
SELECT count(*) AS rows,
       pg_size_pretty(pg_relation_size('mme.application')) AS heap,
       round(pg_relation_size('mme.application')::numeric / count(*), 1) AS bytes_per_row
FROM application;

\echo '-- A6 lender name coverage'
SELECT count(*) AS lenders, count(name) AS with_name FROM lender;

\echo '=================================================================='
\echo 'B. INVESTIGATION 1: A LOAN LIKE MINE'
\echo '=================================================================='
\echo '-- B1 2024 home purchase originations (owner-occupied, first lien): share in $400k-$500k, county vs state'
WITH p AS (
  SELECT county_fips, loan_amount FROM application
  WHERE year = 2024 AND action_taken = 1 AND loan_purpose = 1 AND occupancy = 1 AND lien_status = 1
), st AS (
  SELECT avg((loan_amount BETWEEN 400000 AND 499999)::int) AS state_share FROM p
)
SELECT c.name AS county, count(*) AS purchases,
       round(100 * avg((loan_amount BETWEEN 400000 AND 499999)::int), 1) AS pct_400_500k,
       round(100 * (SELECT state_share FROM st), 1) AS state_pct,
       round(avg((loan_amount BETWEEN 400000 AND 499999)::int) / (SELECT state_share FROM st), 2) AS ratio_to_state,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY loan_amount) AS median_purchase_loan
FROM p JOIN county c USING (county_fips)
GROUP BY c.name ORDER BY ratio_to_state DESC;

\echo '-- B2 jumbo (non-conforming) share of 2024 purchase originations, and where the limit falls'
SELECT c.name AS county, count(*) AS purchases,
       round(100.0 * count(*) FILTER (WHERE conforming = false) / count(*), 1) AS pct_jumbo,
       max(loan_amount) FILTER (WHERE conforming = true) AS largest_conforming_seen,
       min(loan_amount) FILTER (WHERE conforming = false) AS smallest_jumbo_seen
FROM application a JOIN county c USING (county_fips)
WHERE year = 2024 AND action_taken = 1 AND loan_purpose = 1
GROUP BY c.name ORDER BY pct_jumbo DESC;

\echo '-- B3 pricing comparability: per county, lenders with >= 30 similar loans and the spread of their medians'
WITH sim AS (
  SELECT county_fips, lei, interest_rate, total_loan_costs
  FROM application
  WHERE year = 2024 AND action_taken = 1 AND loan_purpose = 1 AND loan_type = 1
    AND lien_status = 1 AND occupancy = 1 AND loan_term = 360
    AND loan_amount BETWEEN 400000 AND 499999 AND interest_rate IS NOT NULL
), per_lender AS (
  SELECT county_fips, lei, count(*) AS n,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY interest_rate) AS med_rate,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY total_loan_costs) AS med_costs
  FROM sim GROUP BY county_fips, lei
)
SELECT c.name AS county,
       (SELECT count(*) FROM sim s WHERE s.county_fips = c.county_fips) AS similar_loans,
       count(*) FILTER (WHERE n >= 30) AS lenders_30plus,
       round(min(med_rate) FILTER (WHERE n >= 30)::numeric, 3) AS lowest_lender_median_rate,
       round(max(med_rate) FILTER (WHERE n >= 30)::numeric, 3) AS highest_lender_median_rate,
       round(min(med_costs) FILTER (WHERE n >= 30)::numeric) AS lowest_median_costs,
       round(max(med_costs) FILTER (WHERE n >= 30)::numeric) AS highest_median_costs
FROM per_lender JOIN county c USING (county_fips)
GROUP BY c.county_fips, c.name ORDER BY lenders_30plus DESC;

\echo '-- B4 example: Middlesex, lenders with >= 30 similar 2024 loans'
SELECT coalesce(l.name, a.lei) AS lender, count(*) AS similar_loans,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY interest_rate) AS median_rate,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY total_loan_costs) AS median_total_costs,
       round(100.0 * count(*) FILTER (WHERE discount_points > 0) / count(*), 1) AS pct_paid_points
FROM application a LEFT JOIN lender l USING (lei)
WHERE year = 2024 AND county_fips = '34023' AND action_taken = 1 AND loan_purpose = 1 AND loan_type = 1
  AND lien_status = 1 AND occupancy = 1 AND loan_term = 360
  AND loan_amount BETWEEN 400000 AND 499999 AND interest_rate IS NOT NULL
GROUP BY 1 HAVING count(*) >= 30 ORDER BY median_rate;

\echo '=================================================================='
\echo 'C. INVESTIGATION 2: MARKET VS. ITS NEIGHBORS'
\echo '=================================================================='
\echo '-- C1 county profile, 2024'
CREATE TEMP TABLE county_profile AS
SELECT a.county_fips,
       count(*) FILTER (WHERE action_taken BETWEEN 1 AND 5) AS applications,
       round(100.0 * count(*) FILTER (WHERE action_taken = 3)
             / nullif(count(*) FILTER (WHERE action_taken IN (1, 2, 3)), 0), 1) AS denial_rate,
       round(100.0 * count(*) FILTER (WHERE action_taken = 4)
             / nullif(count(*) FILTER (WHERE action_taken BETWEEN 1 AND 5), 0), 1) AS withdrawal_rate,
       round(100.0 * count(*) FILTER (WHERE loan_type = 2 AND loan_purpose = 1 AND action_taken BETWEEN 1 AND 5)
             / nullif(count(*) FILTER (WHERE loan_purpose = 1 AND action_taken BETWEEN 1 AND 5), 0), 1) AS fha_share_purchase,
       round(100.0 * count(*) FILTER (WHERE loan_purpose IN (31, 32) AND action_taken BETWEEN 1 AND 5)
             / nullif(count(*) FILTER (WHERE action_taken BETWEEN 1 AND 5), 0), 1) AS refi_share,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY loan_amount) FILTER (WHERE action_taken = 1) AS median_originated
FROM application a WHERE year = 2024
GROUP BY a.county_fips;
SELECT c.name AS county, p.applications, p.denial_rate, p.withdrawal_rate, p.fha_share_purchase, p.refi_share, p.median_originated
FROM county_profile p JOIN county c USING (county_fips) ORDER BY p.denial_rate DESC;

\echo '-- C2 biggest gaps between neighboring NJ counties, 2024 (percentage points)'
SELECT ca.name AS county, cb.name AS neighbor,
       pa.denial_rate AS denial_a, pb.denial_rate AS denial_b, pa.denial_rate - pb.denial_rate AS denial_gap,
       pa.fha_share_purchase - pb.fha_share_purchase AS fha_gap,
       pa.median_originated - pb.median_originated AS median_loan_gap
FROM county_adjacency adj
JOIN county_profile pa ON pa.county_fips = adj.county_fips
JOIN county_profile pb ON pb.county_fips = adj.neighbor_fips
JOIN county ca ON ca.county_fips = adj.county_fips
JOIN county cb ON cb.county_fips = adj.neighbor_fips
WHERE adj.county_fips < adj.neighbor_fips
ORDER BY abs(pa.denial_rate - pb.denial_rate) DESC LIMIT 15;

\echo '-- C3 denial reasons: share of 2024 denials citing each reason, top-denial counties vs state'
WITH d AS (
  SELECT a.application_id, a.county_fips FROM application a WHERE year = 2024 AND action_taken = 3
), r AS (
  SELECT d.county_fips, dr.reason FROM d JOIN application_denial_reason dr USING (application_id)
), tot AS (SELECT county_fips, count(*) AS denials FROM d GROUP BY county_fips),
state AS (
  SELECT reason, round(100.0 * count(*) / (SELECT count(*) FROM d), 1) AS state_pct FROM r GROUP BY reason
)
SELECT c.name AS county, rc.label AS reason, t.denials,
       round(100.0 * count(*) / t.denials, 1) AS pct_of_denials, s.state_pct
FROM r JOIN tot t USING (county_fips) JOIN county c USING (county_fips)
JOIN denial_reason_code rc ON rc.code = r.reason JOIN state s USING (reason)
WHERE r.county_fips IN (SELECT county_fips FROM county_profile ORDER BY denial_rate DESC LIMIT 3)
GROUP BY c.name, rc.label, t.denials, s.state_pct, r.reason
ORDER BY c.name, pct_of_denials DESC;

\echo '-- C4 same lender, different behavior across a county border (>= 100 decided applications on each side, 2024)'
WITH ld AS (
  SELECT county_fips, lei,
         count(*) FILTER (WHERE action_taken IN (1, 2, 3)) AS decided,
         100.0 * count(*) FILTER (WHERE action_taken = 3) / nullif(count(*) FILTER (WHERE action_taken IN (1, 2, 3)), 0) AS denial_rate
  FROM application WHERE year = 2024 GROUP BY county_fips, lei
)
SELECT coalesce(l.name, a.lei) AS lender, ca.name AS county, cb.name AS neighbor,
       a.decided AS decided_a, b.decided AS decided_b,
       round(a.denial_rate, 1) AS denial_a, round(b.denial_rate, 1) AS denial_b,
       round(a.denial_rate - b.denial_rate, 1) AS gap
FROM county_adjacency adj
JOIN ld a ON a.county_fips = adj.county_fips
JOIN ld b ON b.county_fips = adj.neighbor_fips AND b.lei = a.lei
JOIN county ca ON ca.county_fips = adj.county_fips
JOIN county cb ON cb.county_fips = adj.neighbor_fips
LEFT JOIN lender l ON l.lei = a.lei
WHERE adj.county_fips < adj.neighbor_fips AND a.decided >= 100 AND b.decided >= 100
ORDER BY abs(a.denial_rate - b.denial_rate) DESC LIMIT 15;

\echo '=================================================================='
\echo 'D. INVESTIGATION 3: WHAT CHANGED?'
\echo '=================================================================='
\echo '-- D1 refinance applications by county, 2021 vs 2023 vs 2024'
SELECT c.name AS county,
       count(*) FILTER (WHERE year = 2021) AS refi_2021,
       count(*) FILTER (WHERE year = 2023) AS refi_2023,
       count(*) FILTER (WHERE year = 2024) AS refi_2024,
       round(100.0 * (count(*) FILTER (WHERE year = 2023) - count(*) FILTER (WHERE year = 2021))
             / nullif(count(*) FILTER (WHERE year = 2021), 0), 1) AS pct_change_21_23
FROM application a JOIN county c USING (county_fips)
WHERE loan_purpose IN (31, 32) AND action_taken BETWEEN 1 AND 5
GROUP BY c.name ORDER BY pct_change_21_23;

\echo '-- D2 the 20 largest 2021 lenders by NJ originations, and what happened to them'
WITH o AS (
  SELECT lei, year, count(*) AS originations FROM application WHERE action_taken = 1 GROUP BY lei, year
), top AS (SELECT lei FROM o WHERE year = 2021 ORDER BY originations DESC LIMIT 20)
SELECT coalesce(l.name, t.lei) AS lender,
       sum(originations) FILTER (WHERE year = 2021) AS y2021,
       sum(originations) FILTER (WHERE year = 2022) AS y2022,
       sum(originations) FILTER (WHERE year = 2023) AS y2023,
       sum(originations) FILTER (WHERE year = 2024) AS y2024,
       round(100.0 * (sum(originations) FILTER (WHERE year = 2024) - sum(originations) FILTER (WHERE year = 2021))
             / sum(originations) FILTER (WHERE year = 2021), 1) AS pct_change_21_24
FROM top t JOIN o USING (lei) LEFT JOIN lender l USING (lei)
GROUP BY 1 ORDER BY y2021 DESC;

\echo '-- D3 lender entries and exits by county, 2023 -> 2024 (>= 50 originations one year, < 10 the other)'
WITH o AS (
  SELECT county_fips, lei,
         count(*) FILTER (WHERE year = 2023 AND action_taken = 1) AS o23,
         count(*) FILTER (WHERE year = 2024 AND action_taken = 1) AS o24
  FROM application WHERE year IN (2023, 2024) GROUP BY county_fips, lei
)
SELECT c.name AS county, coalesce(l.name, o.lei) AS lender, o.o23, o.o24,
       CASE WHEN o.o23 >= 50 AND o.o24 < 10 THEN 'exited' ELSE 'entered' END AS change
FROM o JOIN county c USING (county_fips) LEFT JOIN lender l USING (lei)
WHERE (o.o23 >= 50 AND o.o24 < 10) OR (o.o24 >= 50 AND o.o23 < 10)
ORDER BY greatest(o.o23, o.o24) DESC LIMIT 25;

\echo '-- D4 unusual denial-rate changes 2023 -> 2024 (z-score across counties)'
WITH r AS (
  SELECT county_fips, year,
         100.0 * count(*) FILTER (WHERE action_taken = 3) / nullif(count(*) FILTER (WHERE action_taken IN (1, 2, 3)), 0) AS denial_rate
  FROM application WHERE year IN (2023, 2024) GROUP BY county_fips, year
), ch AS (
  SELECT county_fips,
         max(denial_rate) FILTER (WHERE year = 2024) - max(denial_rate) FILTER (WHERE year = 2023) AS change
  FROM r GROUP BY county_fips
)
SELECT c.name AS county, round(change, 2) AS change_pts,
       round((change - avg(change) OVER ()) / nullif(stddev_samp(change) OVER (), 0), 2) AS z
FROM ch JOIN county c USING (county_fips) ORDER BY abs((change - avg(change) OVER ()) / nullif(stddev_samp(change) OVER (), 0)) DESC;

\echo '=================================================================='
\echo 'E. STRETCH: NEIGHBORHOOD LENDING GAP (Newark metro counties, 2021)'
\echo '=================================================================='
\echo '-- E1 share of each lender''s applications from majority-minority tracts vs all other lenders (>= 200 applications)'
WITH apps AS (
  SELECT a.lei, (t.minority_pct > 50) AS mm
  FROM application a JOIN census_tract t ON t.tract_fips = a.tract_fips AND t.year = a.year
  WHERE a.year = 2021 AND a.action_taken BETWEEN 1 AND 5
    AND a.county_fips IN ('34013', '34027', '34035', '34037', '34039')
), per AS (
  SELECT lei, count(*) AS n, count(*) FILTER (WHERE mm) AS n_mm FROM apps GROUP BY lei
), tot AS (SELECT sum(n) AS n, sum(n_mm) AS n_mm FROM per)
SELECT coalesce(l.name, p.lei) AS lender, p.n AS applications,
       round(100.0 * p.n_mm / p.n, 1) AS pct_majority_minority,
       round(100.0 * (tot.n_mm - p.n_mm) / (tot.n - p.n), 1) AS peers_pct,
       round((1.0 * p.n_mm / p.n) / ((1.0 * (tot.n_mm - p.n_mm)) / (tot.n - p.n)), 2) AS ratio_to_peers
FROM per p CROSS JOIN tot LEFT JOIN lender l USING (lei)
WHERE p.n >= 200
ORDER BY (l.name ILIKE '%lakeland%') DESC NULLS LAST, ratio_to_peers ASC
LIMIT 20;
