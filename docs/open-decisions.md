# Open Decisions — For the Team Meeting

> Everything the four of us need to agree on together. Bring this to every meeting.
> **How to use it:** anyone can add a decision under "Open". In the meeting, go top to bottom. When the group agrees, move the item to "Decided" with the date and the choice, and copy the reasoning into [`decisions.md`](decisions.md) if it's a design decision (those feed the graded "design alternative" and "engineering difficulties" sections).
> Each item has a **recommendation** so the meeting has a starting point, not a blank page. Disagree freely.

**Next meeting:** date TBD — goal: finalize D1 (which investigations we build).

> **Update (10/10):** the full NJ 2021–2024 data is loaded; real numbers are in [`data-findings.md`](data-findings.md). Rohan settled D2, D3, D7, D9, D10, D16, D17, D19 and D21 (see **Decided** below). Everything still under **Open** is for the meeting.

> **Meeting 10/13** ([notes](meetings/2026-10-13.md)): the team agreed with all of Rohan's decisions. Each member is researching D1 to finalize it at the next meeting. D4: we pick the best stack for the job when building starts.

---

## Open

### 🔴 Must decide before work can start

#### D1. Which guided investigations do we build?
- **Why it matters:** the whole product, the mockups and the pitch are built around these. Professor explicitly asked for real scenarios, not charts.
- **Options:** see [`investigations.md`](investigations.md) for the full research and scoring.
  - A. Recommended set: (1) A loan like mine, (2) Market vs. its neighbors, (3) What changed?, + stretch: Neighborhood lending gap
  - B. Professor's five as-is, built shallowly
  - C. Mix: pick any three from the scored list
- **Recommendation:** A. It covers all five of the professor's examples inside three workflows and adds lender pricing, which no public HMDA tool does.
- **Also decide:** which one we prototype first (recommend #1, the homebuyer one) and which one leads the pitch.
- **Data evidence (10/10):** all four work on the real data ([`data-findings.md`](data-findings.md) §3). Two surprises:
  - The stretch (neighborhood lending gap) is the most compelling result. Lakeland Bank's ratio to peers went 0.27 → 0.47 → 1.10 from 2021 to 2023, around its 2022 DOJ settlement. Consider promoting it to core, or using it as the pitch closer.
  - Denial *reasons* barely differ by county, so professor's example #4 should stay a drill-down inside Investigation 2, not its own investigation.
- **10/13:** each member is looking into which investigations to build. Finalize at the next meeting.

#### D4. Tech stack
- **Backend:** Flask / FastAPI / Django / Streamlit
- **Frontend:** server-rendered templates (Jinja) / React / Streamlit
- **Maps & charts:** Leaflet / Plotly / Mapbox
- **Recommendation:** Flask or FastAPI + Jinja templates + Leaflet (map) + Plotly or Chart.js. Streamlit is fastest to build but per-user roles and URL-level access control are awkward in it, and the final grades enforced access.
- **Constraint:** pick what at least two of us already know.
- **10/13:** the team will pick the best stack for what we need when building starts.

#### D5. Hosting
- **Options:** Neon Postgres + Render web app / Supabase + Render / Render only (256 MB Postgres) / Railway
- **Recommendation:** Neon or Supabase for the database (about 0.5 GB free), Render or Railway for the app.
- **Data evidence (10/10):** after D10 and D16 the database is **211 MB before any secondary indexes** (it was 305 MB). That fits Render's 256 MB free Postgres for now, but the indexes we add from query evidence will take most of the remaining 45 MB, so Render-only is tight.

#### D6. Who owns what?
| Area | Candidate owner |
|---|---|
| Data: download HMDA, write loader, measure rows/sizes/load time | |
| Schema: ERD, `schema.sql`, access rules, design alternative | |
| Prototype + mockups (Investigation 1 first) | |
| Project page + pitch | |
- Everyone also writes the queries for their part into `query-log.md`.

#### D8. Shared repo and workflow
- **Recommendation:** one GitHub repo (this folder), `main` protected, each person works on a branch and opens a PR; one other person reviews. Everyone uses `CLAUDE.md` so AI-generated code follows the same conventions.
- **Also decide:** communication channel (group chat?), and a fixed weekly meeting slot.

### 🟡 Decide before the midterm (project page due 10/23)

#### D11. Pitch structure and who presents what
- Proposed flow (≤ 12 min + questions): the problem (a real homebuyer and a real analyst) → what exists and why it's not enough → live walkthrough of Investigation 1 via mockups → the data and the path to 1M rows → what we expect to be hard.
- **Decide:** speakers per section, rehearsal date (recommend Tue 10/20).

#### D12. Mockup tool
- **Options:** Figma / clickable prototype built with Claude or Replit (professor recommended) / static HTML
- **Recommendation:** a quick clickable prototype; its screenshots are our mockups.

### 📊 Raised by the data (10/10) — evidence in [`data-findings.md`](data-findings.md)

#### D18. What counts as a "similar loan" for price comparisons (Investigation 1)?
- Our drafted rule (same year, $400–500k, ≥ 30 loans per lender) leaves only **7 of 21 counties** with 3+ comparable lenders, none south of Ocean County.

| Rule | Counties with ≥ 3 comparable lenders |
|---|---|
| 2024, $400–500k, ≥ 30 loans | 7 |
| 2024, $400–500k, ≥ 20 | 13 |
| 2024, ±$100k around the user's amount, ≥ 20 | 17 |
| 2023–24 pooled, ±$100k, ≥ 20 | 18 |

- **Recommendation:** same year, ±$100k around the user's amount, at least 20 loans per lender. Always show rate *and* points/costs together, because some lenders buy rates down with points.
- **Also decide (moved from D10):** which pricing fields to keep: interest rate, rate spread, total loan costs, discount points. About +12 bytes per row.

#### D20. Denial reasons: standalone investigation or drill-down?
- In the three highest-denial counties, DTI is cited in 41–44% of denials vs. 40.9% statewide. Reasons differ much more by loan purpose and by lender than by county.
- **Recommendation:** drill-down inside Investigation 2 (already the plan in D1, option A).

### 🟢 Can wait until after the midterm

#### D13. How are plain-language findings generated?
- Templates filled from query results (recommended: every sentence traces to a query) vs. an LLM summarizing results (risk: unverifiable claims).

#### D14. Lender names
- HMDA rows only carry the LEI. Names come from the HMDA reporter panel / transmittal sheet. Decide whether we also tag lender type (bank / credit union / independent mortgage company).

#### D15. User guides
- Who writes each user guide. With D2 decided as guests only, there are no sign-ins for now; revisit if accounts are added before the final.

---

## Decided

| # | Date | Decision | Notes |
|---|---|---|---|
| — | 9/30 | Database: PostgreSQL | From proposal |
| — | 9/30 | Data source: HMDA public LAR | From proposal |
| D2 | 10/10 | Two user types, Homebuyer and Analyst, both as guests with no accounts for now. Admin is not a user type: the yearly data import runs as a script, with no admin screen. | Rohan; team agreed 10/13. Revisit before the final: the final grades user writes, enforced access rules, and a sign-in per user type. Access-rules table in `data-plan.md` updated 10/10. |
| D3 | 10/10 | Data scope: NJ 2021–2024, and every application whatever its outcome (made, denied, withdrawn, ...), except purchased-loan rows (D16). | Rohan; team agreed 10/13. 1,537,805 rows after D16; 2021 is needed to stay over 1M. |
| D7 | 10/10 | Project page on GitHub Pages from this repo. At the final, export it to PDF/Word and upload it to Canvas. | Rohan; team agreed 10/13. Pages is free for public repos (a private repo needs GitHub Pro, free for students via the Student Developer Pack). Needs the repo on GitHub first (D8). |
| D9 | 10/10 | Graded design alternative: precomputed `market_summary` vs. aggregating live. We store the summary table. | Rohan; team agreed 10/13. Data is static between imports; the summary is rebuilt at each import (`etl/load.sh` already does this). Write-up includes timings of live vs. summary. |
| D10 | 10/10 | Working tables store numeric codes (raw files keep text). Shrink the main table as much as possible during cleaning, as long as the data's meaning doesn't change, so the narrow version (integer `lender_id`, smallint county) is in. | Rohan; team agreed 10/13. Measured 213 MB → 164 MB. Which pricing fields to keep moved to D18. |
| D16 | 10/10 | Drop "purchased loan" rows (action 6) at load. Not home-purchase loans; those are all kept. | Rohan; team agreed 10/13. Leaves 1,537,805 rows; saves about 25 MB. |
| D17 | 10/10 | Add a `lender_successor` table (old LEI → new LEI, effective date) so mergers aren't shown as exits. | Rohan; team agreed 10/13. Lakeland → Provident (May 2024) confirmed; verify Caliber and Home Point. |
| D19 | 10/10 | Every denial comparison is per loan purpose, defaulting to home purchase. | Rohan; team agreed 10/13. Purchase 11.3% vs. home improvement 40% statewide. |
| D21 | 10/10 | Name lenders everywhere, with sample sizes and a standard caveat line on lending-gap and cross-county denial views. | Rohan; team agreed 10/13. |

---

## Meeting notes
Keep one file per meeting in [`meetings/`](meetings/), using [`meetings/TEMPLATE.md`](meetings/TEMPLATE.md).
