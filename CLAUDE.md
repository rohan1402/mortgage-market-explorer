# CLAUDE.md — Brief for AI coding tools

Read this before writing code in this repo. Four people use AI assistants here; this file keeps their output consistent.

## Start every session with the status brief
- Before anything else, read **Project status** and **Latest activity** in `README.md` (or run `scripts/status.sh`; Claude Code runs it for you at startup) and tell your user in about five lines: the last change and who made it, the next deadline, what's done, and what's left.
- If you finish or start a task, update **Project status** in `README.md` in the same commit: the deadlines table, "Done so far" (newest first, about 5 items) and "Next up", plus the "Updated" line. Don't edit "Latest activity"; a GitHub Action fills it on every push to `main`.
- Setup is `./setup.sh` (see `README.md`). If it breaks for someone, fix the script rather than adding manual steps.

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
README.md             project status + deadlines (read first), setup
PROJECT.md            master doc
setup.sh              one-command setup: Postgres, database, download, load
db/schema.sql         schema (source of truth)
etl/                  HMDA download + loader (rebuilds from empty DB)
app/                  web application
docs/                 data plan, decisions, query log, investigations, ERD, meetings
scripts/              status brief and README "Latest activity"
```
