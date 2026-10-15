# Mortgage Market Explorer — Master Project Doc

> The single source of truth for what we are building. If something here changes, change it here first.
> Items marked **[OPEN]** are not decided yet; they are listed in [`docs/open-decisions.md`](docs/open-decisions.md) for the next team meeting.

**Course:** Data Management for Advanced Data Science Applications, Fall 2026
**Team:** Alex Goferman, Rohan Pant, Junemo Moon, Juhun Kim
**Last updated:** 2026-10-15

---

## 1. Deadlines

Progress on each one is tracked in the **Project status** section of [`README.md`](README.md).

| Date | What | Points |
|---|---|---|
| Wed 9/30 | Proposal | 3 |
| Thu 10/22 6–9 PM or Fri 10/23 4–6 PM (our signed-up slot) | Midterm pitch, about 15 min of a 20-min slot. No working app or data needed. | 10 |
| **Fri 10/23, end of day** | Project page live (4), with the proposal, ER diagram + schema + data plan (3) and mockups, at least one screen per user type (4). Grading starts 10/24. | 11 |
| Wed 12/9, 11:59 PM | Live app + sample sign-ins (15, of which 3 for ≥1M rows), user guides (4), documented code + project page (8) | 27 |
| Thu 12/10, in class | Final presentation, up to 15 min | 10 |
| Before 12/10 | Bonus: real bugs found in other teams' apps | +2 |

Late = −5 points. Midterm dates from the professor's Canvas notes of 10/9 and 10/12.

---

## 2. Problem

Public HMDA data covers nearly every U.S. mortgage application, but the official tools (the HMDA Data Browser, FFIEC aggregate reports) are built around **filters and tables**. They show statistics; they do not answer questions. A homebuyer or an analyst has to know which filters to set, download files, and do the comparison themselves.

**Professor's feedback (9/30), in short:** the Data Browser already filters, maps and charts. Our value has to come from *answering real questions and drawing conclusions*, through guided investigations, comparisons and interactive maps, not a collection of charts. Full text: [`docs/proposal-feedback.md`](docs/proposal-feedback.md).

## 3. What makes us different (the pitch line)

1. **Starts from a question, not a filter panel.** Every screen is a guided investigation.
2. **Always compares against something:** the state, the neighboring counties, last year, or peer lenders. A number alone means nothing.
3. **Ends with a plain-language finding**, for example "Loans near $400k are about twice as common in Middlesex as statewide." Findings are built from query results with templates, so every sentence traces back to a query.
4. **Remembers and watches.** Analysts save investigations and watch counties or lenders; when the admin loads a new HMDA year, "What changed?" flags what moved. This is also our write path.

## 4. Users and roles

| Role | Who | Comes to do | Can write |
|---|---|---|---|
| Homebuyer | Someone planning a mortgage around a target amount | Find markets where their loan is normal, which lenders do loans like theirs, what similar borrowers paid | Saved searches (own only) **[OPEN: account required, or guest?]** |
| Analyst | Housing researcher, journalist, lender analyst, advocate | Compare markets and lenders, find unusual changes, save and share investigations | Saved investigations, watchlists, notes (own only) |
| Admin | Our team | Import a new HMDA release, rebuild summaries, manage users | Data releases, reference tables, user roles |

Access rules must be **enforced in the app** by the final (not just documented). Full read/write matrix: [`docs/data-plan.md`](docs/data-plan.md#access-rules).

## 5. Guided investigations

Research and recommendation: [`docs/investigations.md`](docs/investigations.md). **[OPEN: final pick of 3]**

Recommended set (covers all five of the professor's examples inside three workflows, plus one thing no public tool does):

| # | Investigation | Role | Covers professor's example |
|---|---|---|---|
| 1 | **A loan like mine:** where is my loan size normal, is it jumbo there, who makes loans like it, and what did people pay | Homebuyer | #1 target loan size, #5 lenders in a market, + pricing (new) |
| 2 | **Market vs. its neighbors:** how a county differs from the counties next door, in lenders, outcomes and denial reasons | Analyst | #2 neighboring counties, #4 denial reasons, #5 lenders in a market |
| 3 | **What changed?** ranked unusual year-over-year shifts for a county or lender | Analyst (watchlist) | #3 unusual changes |
| Stretch | **Neighborhood lending gap:** does a lender reach majority-minority tracts as often as its peers? | Analyst | New |

## 6. Data

- **Source:** HMDA public Loan/Application Register (FFIEC/CFPB), **New Jersey, 2021 to 2024 [OPEN: confirm years]**. About 1.74M applications before cleaning (2021: ~708k, 2022: ~414k, 2023: ~294k, 2024: ~324k).
- **Supporting:** HMDA reporter panel (lender names), Census county adjacency file (neighbors), county and tract reference data (already appended to HMDA rows).
- **Primary table:** `application`, target ≥1M rows after cleaning, narrow and coded.
- Details: [`docs/data-plan.md`](docs/data-plan.md). Schema: [`db/schema.sql`](db/schema.sql). ERD: [`docs/erd.md`](docs/erd.md).

## 7. Stack and hosting **[OPEN]**

- **Database:** PostgreSQL (decided in proposal).
- **Backend:** Flask or FastAPI (recommended) vs. Streamlit vs. Django **[OPEN]**
- **Frontend / map:** server-rendered templates + Leaflet or Plotly maps **[OPEN]**
- **Host:** Neon or Supabase Postgres (about 0.5 GB free) + Render/Railway for the app **[OPEN]**. Render's free Postgres (256 MB) is likely too small for 1.74M rows plus indexes.

## 8. Team and ownership **[OPEN]**

| Area | Owner | Midterm output |
|---|---|---|
| Data (download, loader, row counts, sizes) | TBD | `etl/`, real numbers in `docs/data-plan.md` |
| Schema (ERD, `schema.sql`, access rules, design alternative) | TBD | `db/schema.sql`, `docs/erd.md`, `docs/decisions.md` |
| Prototype + mockups (Investigation 1 first) | TBD | Clickable prototype, screenshots as mockups |
| Project page + pitch | TBD | Project page, pitch outline |

## 9. Midterm plan

| By | Milestone |
|---|---|
| Sun 10/11 or Mon 10/12 | Team meeting: settle everything in `docs/open-decisions.md` |
| Fri 10/16 | Data loaded (at least one year), schema frozen, prototype of Investigation 1 in front of the team |
| Mon 10/19 | Mockups for every user type, project page draft complete |
| Tue 10/20 | Pitch rehearsal (timed, ≤ 12 min to leave room for questions) |
| Thu 10/22 or Fri 10/23 | Pitch, in our signed-up slot |
| **Fri 10/23, end of day** | Project page live with everything on it (grading starts 10/24) |

## 10. Repo map

| File | Holds | Feeds |
|---|---|---|
| `PROJECT.md` | This file | Project page, pitch |
| `docs/open-decisions.md` | Decisions the group still has to make, for meetings | Everything |
| `docs/meetings/` | Meeting notes, one file per meeting | — |
| `docs/investigations.md` | Research on which investigations to build | Project page, pitch, mockups |
| `docs/data-plan.md` | Sources, fields, cleaning, per-table rows and sizes, access rules | ER/data plan (midterm), "Working with the data" (final) |
| `db/schema.sql`, `docs/erd.md` | Schema and ER diagram | ER/data plan |
| `docs/decisions.md` | Decisions made: options, pick, why; things that didn't work | Design alternative, "Engineering difficulties" |
| `docs/query-log.md` | Each real app query with EXPLAIN ANALYZE at 10k/100k/1M | "Behavior at scale" (final) |
| `CLAUDE.md` | Brief for AI coding tools | Keeps code consistent across four people |
| `README.md` | Project status and deadlines, setup | Codebase grade |
