# Decision Log

> Design decisions **after** the team has made them (open ones live in [`open-decisions.md`](open-decisions.md)).
> Feeds the midterm "design alternative" and the final "engineering difficulties" (which must include at least one thing that didn't work). Write entries when they happen; they can't be reconstructed accurately in December.

## Template

### YYYY-MM-DD — Title
- **Context:** what problem forced a choice
- **Options considered:** A … / B …
- **Decision:** …
- **Why:** … (evidence: query timings, sizes, row counts where possible)
- **Status:** decided / revisited on …

---

## Decisions

### 2026-09-30 — PostgreSQL as the database
- **Context:** highly structured HMDA data; graded on inspecting query plans.
- **Options considered:** PostgreSQL / MySQL / MongoDB
- **Decision:** PostgreSQL.
- **Why:** relational fit (applications → lenders, counties), strong `EXPLAIN ANALYZE`, window functions and `percentile_cont` for the investigations, free hosted options (Neon, Supabase).
- **Status:** decided.

### 2026-10-10 — Precomputed `market_summary` instead of aggregating `application` on every request (D9)
- **Context:** Investigations 2 and 3 compare counties and lenders by year. Each comparison is a GROUP BY over `application` (1.54M rows). The data only changes when we import a new HMDA year.
- **Options considered:**
  - A. Aggregate live: every screen runs `COUNT(*) FILTER (...)` over `application`. No extra table, always current.
  - B. Precompute: a `market_summary` table keyed by (`year`, `county_id`, `lender_id`, `loan_purpose`, `loan_type`), rebuilt by `etl/load.sh` after each import.
- **Decision:** B. We store the summary.
- **Why:** the data is static between imports, so a summary can't go stale. `market_summary` has 107,327 rows (7 MB + 4.4 MB index) against 1,537,805 rows in `application` (138 MB), so a county-by-year comparison reads about 14x fewer rows. Investigation 1 still reads the raw rows, because it needs lender medians of rate and costs for a loan-amount range that the user picks.
- **Cost of this choice:** two copies of the same counts, so a bug in the rebuild shows wrong numbers until the next import. `load.sh` rebuilds the summary from scratch each run to keep them consistent.
- **Evidence still to add:** the same "What changed?" query timed both ways on the 10k / 100k / full loads (`query-log.md`, Q-03). The before/after plans are the write-up for the midterm design alternative and the final "behavior at scale" section.
- **Status:** decided 10/10 (Rohan); team agreed 10/13.

### 2026-10-10 — Narrow `application` table: numeric codes and small keys (D10)
- **Context:** the first full load put `application` at 213 MB plus a 37 MB index, and the whole database at 305 MB. Free hosted Postgres is about 256 MB (Render) to 0.5 GB (Neon, Supabase). The course guide says to keep the table that grows large narrow.
- **Options considered:**
  - A. Keep the public file's shape: text labels (`"Loan originated"`), the 20-character LEI, the 5-character county FIPS on every row.
  - B. Store codes: `smallint` codes with labels in lookup tables, a 4-byte `lender_id` instead of the LEI, a 2-byte `county_id` instead of the FIPS. Order the columns 8-, 4-, 2-, 1-byte, then variable width, so Postgres adds no alignment padding.
- **Decision:** B.
- **Why:** measured 129 → 94 bytes per row and 213 MB → 164 MB for `application` before D16; after D16 the whole database is 211 MB. Meaning is unchanged: the lookup tables hold the exact HMDA labels.
- **Cost of this choice:** every screen that shows a label needs a join to a lookup table, and someone reading the raw table sees `action_taken = 3`, not "denied".
- **Status:** decided 10/10 (Rohan); team agreed 10/13.

### 2026-10-10 — Denial reasons in a child table, not four columns on `application`
- **Context:** the HMDA file reports up to four denial reasons per application in four columns (`denial_reason-1` to `-4`). Only denied applications fill them.
- **Options considered:**
  - A. Keep four `smallint` columns on `application`. No join; but "how often is credit history cited?" has to check four columns, and the main table carries four columns that are empty on most rows.
  - B. `application_denial_reason (application_id, reason)`, one row per reported reason, only for denied applications.
- **Decision:** B.
- **Why:** counting any reason is one `GROUP BY reason`, and the main table stays narrower. Size is about even either way (319,827 reason rows: 11 MB + 8 MB index, versus four mostly-NULL columns), so this choice is about query shape, not space.
- **Cost of this choice:** the denial-reasons drill-down in Investigation 2 needs a join back to `application`. `query-log.md` lists "denial table join vs. four columns" as a query to time at all three sizes.
- **Status:** in the schema since 10/10. Timing comparison still to run.

## Things that didn't work
<!-- Required for the final. Log failures as they happen: what we tried, what went wrong, what we did instead. -->

### 2026-10-10 — The first full load did not fit the free tier
- **What we tried:** loading NJ 2021–2024 with the public file's shape (text labels, LEI and FIPS on every row, purchased loans included).
- **What went wrong:** 1,729,199 rows, `application` 213 MB + 37 MB index, database 305 MB, load 84 s. Over Render's 256 MB free Postgres before adding a single secondary index.
- **What we did instead:** D10 (narrow table, numeric codes) and D16 (drop purchased-loan rows, which are not applications). Result: 1,537,805 rows, 94 bytes per row, database 211 MB, load 64 s. Still tight for Render once indexes are added, which is why D5 leans toward Neon or Supabase.
