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
