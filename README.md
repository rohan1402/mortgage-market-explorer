# Mortgage Market Explorer

Guided investigations of New Jersey mortgage markets, built on public HMDA data (2021–2024).
DBMS course project, Fall 2026: Alex Goferman, Rohan Pant, Junemo Moon, Juhun Kim.

> **Just cloned or pulled? Read "Project status" first.** AI assistants: give your user this brief before anything else ([`AGENTS.md`](AGENTS.md)).

## Project status
<!-- status:start -->
_Updated 2026-10-18. When you finish or start a task, update this section in the same commit._

**Where we are:** the data and schema are done, and the midterm work is split (owners below). Everything is to be finalized by **Tue 10/20, 3:00 PM**. We pitch **Thu 10/22, 6–9 PM**, and the project page is due **Fri 10/23, end of day** (grading starts 10/24).

### Deadlines
| Due | Deliverable | Pts | Owner | Status |
|---|---|---|---|---|
| Wed 9/30 | Proposal | 3 | Team | ✅ Submitted |
| **Tue 10/20, 3:00 PM** | _Team target:_ all midterm work finalized, everyone's GitHub username in | | Everyone | 🟡 All four of us are on GitHub; midterm work in progress |
| **Thu 10/22, 6–9 PM** (our slot) | Midterm pitch, up to 15 min: introduction and problem (7 min), ER diagram and mockups (3 min), where the data comes from and why it's hard (5 min). No working app needed. | 10 | Alex, Junemo, Rohan (in that order) | ⬜ Not started |
| **Fri 10/23, end of day** | Project page live on Canvas: a midterm page with the ER diagram, schema, data plan and mockups (the proposal already has its own page) | 4 | Alex, Rohan | 🟡 Draft: [docs/midterm-page.md](docs/midterm-page.md). Mockups still to add; not on Canvas yet. |
| **Fri 10/23, end of day** | ER diagram, schema and data plan (on the page) | 3 | Juhun | ✅ Done: [ERD](docs/erd.md), [schema](db/schema.sql), [data plan](docs/data-plan.md) (PR #3 merged 10/18). On the draft page. |
| **Fri 10/23, end of day** | Mockups, at least one screen per user type (on the page) | 4 | Junemo | 🟡 In progress |
| Wed 12/9, 11:59 PM | Live app + sample sign-ins (3 of the 15 pts for ≥1M rows) | 15 | TBD | 🟡 1.54M rows load locally. App not started (stack D4, host D5 open). |
| Wed 12/9, 11:59 PM | User guides | 4 | TBD | ⬜ Not started |
| Wed 12/9, 11:59 PM | Documented code + project page | 8 | TBD | ⬜ Not started |
| Thu 12/10, in class | Final presentation, up to 15 min | 10 | TBD | ⬜ Not started |
| Before 12/10 | Bonus: real bugs found in other teams' apps | +2 | Anyone | — |

✅ done · 🟡 in progress · ⬜ not started. Late = −5 points. Midterm owners and pitch split are from the team's plan for 10/22. Course dates: professor's Canvas notes of 10/9 and 10/12.

### Done so far (newest first, keep about 5)
- **10/18** Four investigations, with denial reasons as its own (Denial patterns). D1 and D20 decided; docs and midterm page updated.
- **10/18** ERD, design alternatives and query log merged (PR #3).
- **10/18** Midterm page drafted: [docs/midterm-page.md](docs/midterm-page.md).
- **10/18** The project page will be a live Canvas page, as the course requires (D7 updated).
- **10/10** NJ HMDA 2021–2024 loaded: 1,537,805 applications, 211 MB, rebuilds from empty in about a minute.

### Next up
1. Finalize every midterm piece by Tue 10/20, 3:00 PM.
2. Put the midterm page on Canvas from [docs/midterm-page.md](docs/midterm-page.md) and add the mockups.
3. Rehearse the pitch before Thu 10/22.

Still open: D4, D5, D8, D12–D15, D18 ([open decisions](docs/open-decisions.md)). D6 and D11 are covered by the team plan above.
<!-- status:end -->

### Latest activity
_Filled in automatically on every push to `main`. Run `scripts/status.sh` to see this brief in your terminal._
<!-- activity:start -->

- 2026-10-18 · Rohan Pant · Merged PR #3: Docs: complete ERD, design alternatives, 10/16 meeting and owners
- 2026-10-18 · Rohan Pant · Merged PR #5: Midterm page draft, viewable on GitHub
- 2026-10-18 · Rohan Pant · Merged PR #4: Project page is a live Canvas page (D7)
- 2026-10-18 · Rohan Pant · Merged PR #2: README status brief with deadlines, and one-command setup
- 2026-10-15 · Rohan Pant · Merged PR #1: Docs: sync data plan, findings, open decisions and 10/13 meeting notes

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
