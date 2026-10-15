# Mortgage Market Explorer

Guided investigations of New Jersey mortgage markets, built on public HMDA data (2021–2024).
DBMS course project, Fall 2026 — Alex Goferman, Rohan Pant, Junemo Moon, Juhun Kim.

- **What we're building and why:** [`PROJECT.md`](PROJECT.md)
- **Decisions still open for the team:** [`docs/open-decisions.md`](docs/open-decisions.md)
- **Live site:** _TBD_

## Setup (to be completed once the stack is chosen)

```bash
# 1. Create the database and schema (rebuilds from empty)
psql "$DATABASE_URL" -f db/schema.sql

# 2. Load HMDA data (script TBD in etl/)
# python etl/load_hmda.py --state NJ --years 2021 2022 2023 2024

# 3. Run the app (TBD)
```

Environment variables go in `.env` (not committed): `DATABASE_URL`, `SECRET_KEY`.

## Repo layout
| Path | Contents |
|---|---|
| `PROJECT.md` | Master project doc |
| `CLAUDE.md` | Conventions for AI coding tools |
| `db/` | `schema.sql` |
| `etl/` | Data download and load scripts |
| `app/` | Web application |
| `docs/` | Data plan, ERD, investigations research, decision log, query log, meeting notes |
