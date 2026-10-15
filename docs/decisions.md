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

## Things that didn't work
<!-- Required for the final. Log failures as they happen: what we tried, what went wrong, what we did instead. -->
