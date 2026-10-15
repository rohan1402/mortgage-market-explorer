# Data Plan

> Feeds the midterm "ER diagram, schema and data plan" (3 pts) and the final "Working with the data" section.
> Numbers marked *est.* are estimates; everything else is measured. Re-measure after each load with `etl/load.sh` (it prints the report).

## Sources

| Source | What we take | How we get it |
|---|---|---|
| HMDA public Loan/Application Register (FFIEC/CFPB) | One row per mortgage application, NJ, 2021–2024, every outcome except purchased loans **[D3, D16]** | Data Browser CSV download per year |
| HMDA Data Browser filers list | Lender name by LEI | Data Browser `filers` API, per year |
| Lender mergers | Which lender became which, and when **[D17]** | Verified by hand from press releases, kept in `etl/lender_successor.csv` |
| U.S. Census county adjacency file | Which counties border which | census.gov reference files |
| Census TIGER/Line cartographic boundaries | County and tract shapes for the map | census.gov (GeoJSON after conversion; served as static files, not stored in Postgres) |

All data is **real, public data**. Nothing is generated for now: Homebuyer and Analyst use the site as guests, so there are no user accounts **[D2]**. If accounts are added before the final, demo users and their saved investigations/watchlists will be generated.

## Rows per table

| Table | Rows | Source | Written by |
|---|---|---|---|
| `application` | **1,537,805** | HMDA LAR | Import script (`etl/load.sh`) |
| `application_denial_reason` | **319,827** | HMDA LAR | Import script |
| `market_summary` | **107,327** | Derived from `application` **[D9]** | Import script |
| `lender` | **1,269** | Filers list | Import script |
| `lender_successor` | **1** (Lakeland Bank → Provident Bank, 2024-05-16) | Hand-verified **[D17]** | Import script, from `etl/lender_successor.csv` |
| `county` | 21 NJ counties | Census | Seed script |
| `county_adjacency` | **116** | Census | Import script |
| `census_tract` | **8,464** (tract × year) | HMDA census fields | Import script |
| lookup tables | 3–19 each | HMDA data dictionary | Seed script |
| `data_release` | 4 (one per year) | Import log | Import script |
| `app_user`, `saved_investigation`, `watchlist_item` | 0 for now **[D2]** | Users | Owner user (once accounts exist) |

## Cleaning rules
- Drop purchased loans (`action_taken` 6): they are loans bought from another lender, not applications **[D16]**. Keep every other outcome (1–5, 7, 8) **[D3]**.
- Drop rows with a missing or non-NJ county, a missing LEI, or no loan amount.
- Counts per drop reason are stored in `data_release.rows_dropped`.
- `loan_amount` is stored as reported: the public file uses $10k band midpoints (confirmed on the first load).
- Pricing fields (`interest_rate`, `rate_spread`, `total_loan_costs`, `discount_points`): HMDA reports "NA"/"Exempt" for non-originated loans and some small lenders → stored as NULL. Which ones we keep is still open **[D18]**.
- `conforming_loan_limit`: C → true, NC → false, U/NA → NULL.
- Denial reasons 1–9 from `denial_reason-1..4` → rows in `application_denial_reason`, skipping 10 (not applicable) and 1111 (exempt).
- Store codes, not text: lender as an integer `lender_id`, county as a smallint `county_id`, census tract as a number **[D10]**.

## Rows dropped at load

| Year | Rows read | Purchased loans (D16) | County missing or not NJ | No loan amount | Rows loaded |
|---|---|---|---|---|---|
| 2021 | 707,685 | 78,888 | 1,959 | 300 | 626,538 |
| 2022 | 414,459 | 47,487 | 3,515 | 312 | 363,145 |
| 2023 | 293,775 | 32,075 | 1,577 | 162 | 259,961 |
| 2024 | 323,940 | 33,936 | 1,704 | 139 | 288,161 |
| **Total** | **1,739,859** | **192,386** | **8,755** | **913** | **1,537,805** |

## Measured sizes

The narrow `application` table **[D10]** measures **94 bytes per row** (first load: 129). Its columns are ordered 8-, 4-, 2-, 1-byte, then variable width, so Postgres adds no alignment padding.

| Table | Rows | Table size | Index size |
|---|---|---|---|
| application | 1,537,805 | 138 MB | 33 MB (PK only) |
| application_denial_reason | 319,827 | 11 MB | 8 MB |
| market_summary | 107,327 | 7 MB | 4.4 MB |
| census_tract | 8,464 | 0.5 MB | 0.4 MB |
| lender | 1,269 | 0.2 MB | 0.2 MB |
| county_adjacency | 116 | — | — |
| **Whole database** | | **211 MB** | |

`etl/load.sh` rebuilds everything from empty in **64 s** (2026-10-10, Rohan's Mac, Postgres 16).

First full load, before D10 and D16 (for the write-up): 1,729,199 rows, `application` 213 MB + 37 MB index, database 305 MB, 84 s.

## Access rules

Two user types, both guests for now, and no admin screen **[D2]**. The visitor picks Homebuyer or Analyst on entry; the server checks that choice on every route, not just by hiding buttons. Before the final we revisit accounts, since the final grades sign-ins per user type and user writes.

| Data | Homebuyer | Analyst | Import script (`etl/load.sh`, run by the team) |
|---|---|---|---|
| HMDA data (`application`, summaries, lenders, counties) | Read | Read | Rebuild from empty |
| Investigations | Run Inv. 1 (A loan like mine) | Run all | — |
| `lender_successor` | Read (through results) | Read | Write, from `etl/lender_successor.csv` |
| `data_release` | — | Read (release dates, rows dropped) | Write |
| `app_user`, `saved_investigation`, `watchlist_item` | Not used until accounts exist | Not used until accounts exist | — |
