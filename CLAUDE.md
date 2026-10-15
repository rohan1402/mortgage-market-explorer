# CLAUDE.md — Brief for AI coding tools

Read this before writing code in this repo. Four people use AI assistants here; this file keeps their output consistent.

## What this is
Mortgage Market Explorer: a web app that answers real questions about New Jersey mortgage markets using public HMDA data (2021–2024, ≥1M application rows). It is a graduate DBMS course project; the database design and query performance are graded as heavily as the app. Full context: `PROJECT.md`. Investigations we build: `docs/investigations.md`.

## Ground rules
- **The schema lives in `db/schema.sql`.** Never create or alter tables from app code or ORM auto-migrations. Change `schema.sql`, update `docs/erd.md`, and note the reason in `docs/decisions.md`.
- **Write SQL by hand** (parameterized, no string formatting). We have to explain and `EXPLAIN` every query the app runs. No ORM query builders for the HMDA tables.
- **Every new query the app runs goes into `docs/query-log.md`** with its screen and plan.
- **Do not add indexes speculatively.** Add one only with before/after `EXPLAIN ANALYZE` evidence logged in `docs/query-log.md`.
- **Access control is enforced server-side** on every route and query (role check + `user_id` ownership for saved items). Hiding a button is not access control.
- **Findings sentences come from templates filled with query results.** Do not have an LLM write claims about the data at runtime.
- **Keep `application` narrow:** smallint codes, no text columns, no wide JSON.
- **Minimum-volume rules:** never rank or compare markets/lenders below the agreed minimum count (default 30).
- Secrets (`DATABASE_URL`, session keys) come from environment variables / `.env`, which is git-ignored.

## Stack
**[OPEN — D4/D5 in docs/open-decisions.md]** PostgreSQL is decided. Update this section once the backend, frontend and host are chosen.

## Layout
```
PROJECT.md            master doc
db/schema.sql         schema (source of truth)
etl/                  HMDA download + loader (rebuilds from empty DB)
app/                  web application
docs/                 data plan, decisions, query log, investigations, ERD, meetings
```
