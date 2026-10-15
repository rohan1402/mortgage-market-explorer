# Mortgage Market Explorer

Guided investigations of New Jersey mortgage markets, built on public HMDA data (2021–2024).
DBMS course project, Fall 2026: Alex Goferman, Rohan Pant, Junemo Moon, Juhun Kim.

> **Just cloned or pulled? Read "Project status" first.** AI assistants: give your user this brief before anything else ([`AGENTS.md`](AGENTS.md)).

## Project status
<!-- status:start -->
_Updated 2026-10-15 by Rohan. When you finish or start a task, update this section in the same commit._

**Where we are:** the data and schema are done. The mockups are in progress, and the project page and pitch are not started. We pitch **Thu 10/22, 6–9 PM**, and the project page is due **Fri 10/23, end of day** (grading starts 10/24). The blocker is **D1**, which investigations we build: the team picks them at the next meeting (date TBD).

### Deadlines
| Due | Deliverable | Pts | Owner | Status |
|---|---|---|---|---|
| Wed 9/30 | Proposal | 3 | Team | ✅ Submitted |
| **Thu 10/22, 6–9 PM** (our slot) | Midterm pitch, about 15 min, pitched like to investors: our idea, how we differ, mockups. No working app needed. | 10 | TBD | ⬜ Not started |
| **Fri 10/23, end of day** | Project page live, with the proposal, ER diagram, schema, data plan and mockups | 4 | TBD | ⬜ Not started |
| **Fri 10/23, end of day** | ER diagram, schema and data plan (on the page) | 3 | TBD | 🟡 Written in the repo: [ERD](docs/erd.md), [schema](db/schema.sql), [data plan](docs/data-plan.md). Not on the page yet. |
| **Fri 10/23, end of day** | Mockups, at least one screen per user type (on the page) | 4 | TBD | 🟡 In progress |
| Wed 12/9, 11:59 PM | Live app + sample sign-ins (3 of the 15 pts for ≥1M rows) | 15 | TBD | 🟡 1.54M rows load locally. App not started (stack D4, host D5 open). |
| Wed 12/9, 11:59 PM | User guides | 4 | TBD | ⬜ Not started |
| Wed 12/9, 11:59 PM | Documented code + project page | 8 | TBD | ⬜ Not started |
| Thu 12/10, in class | Final presentation, up to 15 min | 10 | TBD | ⬜ Not started |
| Before 12/10 | Bonus: real bugs found in other teams' apps | +2 | Anyone | — |

✅ done · 🟡 in progress · ⬜ not started. Late = −5 points. Owners are open decision D6. Source: professor's Canvas notes of 10/9 and 10/12.

### Done so far (newest first, keep about 5)
- **10/15** Repo on GitHub, with one-command setup.
- **10/13** Team meeting: agreed to D2, D3, D7, D9, D10, D16, D17, D19, D21 ([notes](docs/meetings/2026-10-13.md)).
- **10/10** NJ HMDA 2021–2024 loaded: 1,537,805 applications, 211 MB, rebuilds from empty in about a minute.
- **10/10** Schema matches every agreed decision. First findings on the real data: [data-findings.md](docs/data-findings.md).

### Next up
1. Next meeting: pick the investigations (D1) and owners (D6). The page, mockups and pitch all build on D1.
2. Check where the project page must live. The 10/9 note talks about editing "your project page" and points to example pages on the course's Canvas Pages, but we chose GitHub Pages (D7).
3. Build the project page and put the proposal, ERD, schema, data plan and mockups on it.
4. Mockups: at least one screen per user type (homebuyer, analyst).
5. Write and rehearse the pitch.

Still open: D1, D4, D5, D6, D8, D11–D15, D18, D20 ([open decisions](docs/open-decisions.md)).
<!-- status:end -->

### Latest activity
_Filled in automatically on every push to `main`. Run `scripts/status.sh` to see this brief in your terminal._
<!-- activity:start -->

- 2026-10-15 · Rohan Pant · Merged PR #1: Docs: sync data plan, findings, open decisions and 10/13 meeting notes
- 2026-10-15 · Rohan Pant · Initial commit: schema, loader, analysis scripts and project docs

<!-- activity:end -->

## Setup

One command sets up everything on macOS, Linux, or Windows with WSL:

```bash
git clone https://github.com/rohan1402/mortgage-market-explorer.git
cd mortgage-market-explorer
./setup.sh
```

It's safe to run again; it skips whatever is already done. It:
1. Installs PostgreSQL 16 if you don't have it (Homebrew on macOS, apt on Linux and WSL) and starts it.
2. Creates the local database `mme`.
3. Downloads NJ HMDA 2021–2024, lender names and county neighbors into `data/raw/` (about 660 MB, not committed).
4. Loads everything with `etl/load.sh` (about a minute).
5. Turns on a git hook that prints the project status after every `git pull`.

Check it worked: `psql mme -c "SELECT count(*) FROM mme.application"` should print 1537805.

| Need | Command |
|---|---|
| Quick start with one year (about 110 MB) | `YEARS=2023 ./setup.sh` |
| Rebuild the database from empty | `RELOAD=1 ./setup.sh` |
| Use a hosted database instead of a local one | `DATABASE_URL=postgresql://... ./setup.sh` |
| See the project status again | `scripts/status.sh` |

**Windows:** open PowerShell as administrator, run `wsl --install`, restart, open "Ubuntu", then run the commands above in it.
**macOS without Homebrew:** install it from [brew.sh](https://brew.sh) first, or use [Postgres.app](https://postgresapp.com).

The app itself is not built yet (stack D4). Its setup goes here once it is.

## Repo layout
| Path | Contents |
|---|---|
| `PROJECT.md` | Master project doc |
| `CLAUDE.md`, `AGENTS.md` | Rules for AI coding tools |
| `setup.sh` | One-command setup (above) |
| `db/` | `schema.sql` |
| `etl/` | Data download (`download.sh`) and load (`load.sh`) |
| `app/` | Web application |
| `docs/` | Data plan, ERD, investigations research, decision log, query log, meeting notes |
| `scripts/` | `status.sh` (project brief), `latest-activity.sh` (fills "Latest activity") |
