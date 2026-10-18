# Query Log — Behavior at Scale

> The biggest written section of the final. Log **queries the app actually runs**, not invented ones.
> For each: the SQL, which screen runs it, and `EXPLAIN (ANALYZE, BUFFERS)` output at 10k, 100k and 1M+ rows, before and after each change.
> "We added an index and it got faster" with no plan and no timing earns close to nothing.

## How to measure
```sql
-- Warm the cache once, then run 3 times and record the median execution time
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;

-- Sizes
SELECT relname, pg_size_pretty(pg_relation_size(relid)) AS table,
       pg_size_pretty(pg_indexes_size(relid)) AS indexes
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;
```
Data subsets: load 10k / 100k / full using the same loader with a row limit, so every query is tested at all three sizes.

## Template

### Q-NN — Short name
- **Screen:** Investigation N, step M
- **SQL:**
```sql
```
- **Results:**

| Rows in `application` | Change | Plan (scan type) | Time (ms) |
|---|---|---|---|
| 10k | baseline | | |
| 100k | baseline | | |
| 1M+ | baseline | | |
| 1M+ | + index on (…) | | |

- **What we learned:**

---

## Queries
<!-- Expected heavy hitters (from docs/investigations.md):
  - Inv 1: loan-amount band share by county vs. state (range filter + group by)
  - Inv 1: lender medians of rate / costs for similar loans (percentile_cont)
  - Inv 2: county vs. neighbors across many measures (adjacency join, conditional aggregation)
  - Inv 2: denial reason shares (denial table join vs. four columns)
  - Inv 3: year-over-year changes with LAG() — summary table vs. raw aggregation
  - Stretch: lender vs. peer share in majority-minority tracts
-->

### Q-03 — What changed? Counties whose year-over-year change is unusual
- **Screen:** Investigation 3, step 1 (the ranked list of counties). Also the D9 design-alternative evidence: the same question from `market_summary` (A) and straight from `application` (B).
- **What "unusual" means:** for each county and year, the percent change in home-purchase originations from the previous year (`LAG()`). A county is flagged when that change is more than 2 standard deviations from the average county's change in the same year. Counties with fewer than 30 originations in the previous year are skipped (minimum-volume rule), because small counties swing a lot by chance.
- **Checked:** both variants run against `db/schema.sql` + `etl/seed_reference.sql` and return identical rows (Juhun, 10/17, synthetic rows). On the real full load (10/18) they also return identical rows: Salem 2022 (z = 2.89), Salem 2023 (2.07) and Cumberland 2022 (2.04).
- **SQL (A, from `market_summary`):**
```sql
WITH yearly AS (
    SELECT county_id, year, SUM(originations) AS originations
    FROM mme.market_summary
    WHERE loan_purpose = 1                                   -- home purchase (D19)
    GROUP BY county_id, year
), change AS (
    SELECT county_id, year, originations,
           LAG(originations) OVER (PARTITION BY county_id ORDER BY year) AS prev
    FROM yearly
), pct AS (
    SELECT county_id, year, prev, originations,
           100.0 * (originations - prev) / prev AS pct_change
    FROM change
    WHERE prev >= 30                                         -- minimum-volume rule
), scored AS (
    SELECT p.*,
           (pct_change - AVG(pct_change) OVER (PARTITION BY year))
             / NULLIF(STDDEV_SAMP(pct_change) OVER (PARTITION BY year), 0) AS z
    FROM pct p
)
SELECT c.name AS county, s.year, s.prev, s.originations,
       ROUND(s.pct_change, 1) AS pct_change, ROUND(s.z, 2) AS z
FROM scored s
JOIN mme.county c USING (county_id)
WHERE ABS(s.z) >= 2
ORDER BY ABS(s.z) DESC, s.year;
```
- **SQL (B, from `application`):** identical except the first CTE:
```sql
WITH yearly AS (
    SELECT county_id, year, COUNT(*) FILTER (WHERE action_taken = 1) AS originations
    FROM mme.application
    WHERE loan_purpose = 1
    GROUP BY county_id, year
), ...
```
- **Results:**

| Rows in `application` | Variant | Plan (scan type) | Time (ms) |
|---|---|---|---|
| 10k (9,867) | B, live | Seq Scan on `application` | 2.6 |
| 10k (9,867) | A, summary | Seq Scan on `market_summary` | 1.4 |
| 100k (98,512) | B, live | Seq Scan on `application` | 17 |
| 100k (98,512) | A, summary | Seq Scan on `market_summary` | 5.2 |
| 1.54M (1,537,805) | B, live | Parallel Seq Scan on `application` | 97 |
| 1.54M (1,537,805) | A, summary | Seq Scan on `market_summary` | 21 |
| 1.54M (1,537,805) | B + index on (`loan_purpose`, `county_id`, `year`) | Parallel Seq Scan; the index is not used | 96 |
| 1.54M (1,537,805) | B + covering index on (`loan_purpose`, `county_id`, `year`) INCLUDE (`action_taken`) | Parallel Index Only Scan, Heap Fetches 0 (after VACUUM) | 57 |

- **How it was timed (10/18):** PostgreSQL 16, each load built with `etl/load.sh` (`SAMPLE=10000`, `SAMPLE=100000`, full). Each time is the median "Execution Time" of 7 `EXPLAIN ANALYZE` runs after one warm-up run. The two index rows were timed with the index created, then dropped again; neither index is in `db/schema.sql`.
- **What we learned:**
  - The summary table (A) is faster at every size, and the gap grows with the data: about 2x at 10k, 3x at 100k and 4.5x at 1.54M rows. This is the evidence for D9 (`decisions.md`).
  - The plain index is not used. Home purchases (`loan_purpose = 1`) are 38% of all rows, so Postgres reads the whole table anyway (96 ms, same as no index).
  - The covering index is used (index-only scan, 57 ms), but it adds 33 MB and is still slower than reading `market_summary` (21 ms). We did not add it. Logged under "Things that didn't work" in `decisions.md`.
- **Next step for the screen:** clicking a flagged county runs the same shape grouped by `lender_id` (joined through `lender_successor`, D17) and by `loan_purpose`, to show what moved.
