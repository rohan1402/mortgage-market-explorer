-- Follow-up checks run 2026-10-10 after the first full load (see docs/data-findings.md).
-- Run: psql "$DATABASE_URL" -X -P pager=off -f analysis/followup_checks.sql
SET search_path TO mme;
-- Written for the first-load schema (lei and county_fips on application). Since D10 the table
-- stores lender_id and county_id; this temporary view puts the old columns back so the checks
-- run unchanged. App queries should join lender / county on the ids directly.
CREATE TEMP VIEW application AS
SELECT a.*, l.lei, c.county_fips
FROM mme.application a JOIN mme.lender l USING (lender_id) JOIN mme.county c USING (county_id);
\pset footer off
\echo '== F1 Cape May jumbo oddity: 2024 purchase originations by conforming flag and amount band'
SELECT conforming, occupancy, count(*), min(loan_amount), percentile_cont(0.5) within group (order by loan_amount) med, max(loan_amount)
FROM application WHERE year=2024 AND county_fips='34009' AND action_taken=1 AND loan_purpose=1 GROUP BY 1,2 ORDER BY 1,2;
\echo '== F1b statewide: NC loans under $766,550 in 2024 purchases, by county'
SELECT c.name, count(*) FILTER (WHERE conforming=false AND loan_amount<766550) nc_under_baseline, count(*) FILTER (WHERE conforming=false) nc_all,
 count(*) FILTER (WHERE conforming=false AND loan_amount<766550 AND lien_status=2) nc_under_2nd_lien,
 count(*) FILTER (WHERE conforming=false AND loan_amount<766550 AND loan_type<>1) nc_under_govt
FROM application a JOIN county c USING (county_fips) WHERE year=2024 AND action_taken=1 AND loan_purpose=1 GROUP BY 1 ORDER BY 2 DESC LIMIT 8;
\echo '== F2 denial rate by purpose statewide 2024'
SELECT p.label, count(*) FILTER (WHERE action_taken IN (1,2,3)) decided,
 round(100.0*count(*) FILTER (WHERE action_taken=3)/nullif(count(*) FILTER (WHERE action_taken IN (1,2,3)),0),1) denial_rate
FROM application a JOIN loan_purpose_code p ON p.code=a.loan_purpose WHERE year=2024 GROUP BY 1 ORDER BY 3 DESC;
\echo '== F3 home purchase denial rate by county 2024, with FHA share'
SELECT c.name, count(*) FILTER (WHERE action_taken IN (1,2,3)) decided,
 round(100.0*count(*) FILTER (WHERE action_taken=3)/nullif(count(*) FILTER (WHERE action_taken IN (1,2,3)),0),1) purchase_denial_rate
FROM application a JOIN county c USING (county_fips) WHERE year=2024 AND loan_purpose=1 GROUP BY 1 ORDER BY 3 DESC;
\echo '== F4 denial reasons by purpose 2024 (share of denials citing reason)'
WITH d AS (SELECT application_id, loan_purpose FROM application WHERE year=2024 AND action_taken=3)
SELECT p.label purpose, rc.label reason, round(100.0*count(*)/(SELECT count(*) FROM d d2 WHERE d2.loan_purpose=d.loan_purpose),1) pct
FROM d JOIN application_denial_reason r USING (application_id) JOIN denial_reason_code rc ON rc.code=r.reason JOIN loan_purpose_code p ON p.code=d.loan_purpose
WHERE d.loan_purpose IN (1,2,31,32,4) GROUP BY d.loan_purpose,p.label,rc.label HAVING 100.0*count(*)/(SELECT count(*) FROM d d2 WHERE d2.loan_purpose=d.loan_purpose) >= 15 ORDER BY 1,3 DESC;
\echo '== F5 Lakeland and Provident originations by year'
SELECT l.name, a.year, count(*) FILTER (WHERE action_taken=1) originations, count(*) apps
FROM application a JOIN lender l USING (lei) WHERE l.name ILIKE '%lakeland%' OR l.name ILIKE 'provident bank%' GROUP BY 1,2 ORDER BY 1,2;
\echo '== F6 Lakeland vs peers, majority-minority tract share, Newark MD counties, by year'
WITH apps AS (
  SELECT a.year, a.lei, (t.minority_pct > 50) mm FROM application a JOIN census_tract t ON t.tract_fips=a.tract_fips AND t.year=a.year
  WHERE a.action_taken BETWEEN 1 AND 5 AND a.county_fips IN ('34013','34027','34035','34037','34039')
), per AS (SELECT year, lei, count(*) n, count(*) FILTER (WHERE mm) n_mm FROM apps GROUP BY 1,2),
tot AS (SELECT year, sum(n) n, sum(n_mm) n_mm FROM per GROUP BY 1)
SELECT p.year, l.name, p.n, round(100.0*p.n_mm/p.n,1) pct_mm, round(100.0*(t.n_mm-p.n_mm)/(t.n-p.n),1) peers_pct,
 round((1.0*p.n_mm/p.n)/((1.0*(t.n_mm-p.n_mm))/(t.n-p.n)),2) ratio
FROM per p JOIN tot t USING (year) JOIN lender l USING (lei) WHERE l.name ILIKE '%lakeland%' OR l.name ILIKE 'provident bank%' ORDER BY 2,1;
\echo '== F7 pricing comparability under looser rules (2024; and 2023-24 pooled), counties with >=3 comparable lenders'
WITH base AS (
  SELECT year, county_fips, lei, loan_amount, interest_rate FROM application
  WHERE action_taken=1 AND loan_purpose=1 AND loan_type=1 AND lien_status=1 AND occupancy=1 AND loan_term=360 AND interest_rate IS NOT NULL
), rules(rule, y0, lo, hi, minn) AS (VALUES
  ('2024, 400-500k, n>=30', 2024, 400000, 499999, 30),
  ('2024, 400-500k, n>=20', 2024, 400000, 499999, 20),
  ('2024, 350-550k, n>=30', 2024, 350000, 549999, 30),
  ('2024, 350-550k, n>=20', 2024, 350000, 549999, 20),
  ('2023-24, 350-550k, n>=20', 2023, 350000, 549999, 20)),
per AS (
  SELECT r.rule, b.county_fips, b.lei, count(*) n FROM rules r JOIN base b ON b.year >= r.y0 AND b.loan_amount BETWEEN r.lo AND r.hi
  GROUP BY 1,2,3 HAVING count(*) >= max(r.minn)
)
SELECT rule, count(DISTINCT county_fips) FILTER (WHERE true) counties_with_any,
 (SELECT count(*) FROM (SELECT county_fips FROM per p2 WHERE p2.rule=per.rule GROUP BY 1 HAVING count(*)>=3) x) counties_with_3plus,
 count(*) lender_county_pairs
FROM per GROUP BY rule ORDER BY rule;
\echo '== F8 statewide applications by purpose 2021 vs 2023'
SELECT CASE WHEN loan_purpose IN (31,32) THEN 'refi' WHEN loan_purpose=1 THEN 'purchase' ELSE 'other' END k,
 count(*) FILTER (WHERE year=2021) y21, count(*) FILTER (WHERE year=2023) y23, count(*) FILTER (WHERE year=2024) y24,
 round(100.0*(count(*) FILTER (WHERE year=2023)-count(*) FILTER (WHERE year=2021))/count(*) FILTER (WHERE year=2021),1) chg_21_23
FROM application WHERE action_taken BETWEEN 1 AND 5 GROUP BY 1;
\echo '== F9 Middlesex: rate + points (2024 similar loans) for the 4 comparable lenders'
SELECT l.name, count(*) n, percentile_cont(0.5) within group (order by interest_rate) med_rate,
 percentile_cont(0.5) within group (order by coalesce(discount_points,0)) med_points, round(avg(coalesce(discount_points,0))) avg_points,
 percentile_cont(0.5) within group (order by total_loan_costs) med_costs
FROM application a JOIN lender l USING (lei)
WHERE year=2024 AND county_fips='34023' AND action_taken=1 AND loan_purpose=1 AND loan_type=1 AND lien_status=1 AND occupancy=1 AND loan_term=360
 AND loan_amount BETWEEN 400000 AND 499999 AND interest_rate IS NOT NULL
GROUP BY 1 HAVING count(*)>=30 ORDER BY 3;
-- F10 (narrow-table size test) is now the real schema (D10); sizes are in docs/data-plan.md.
