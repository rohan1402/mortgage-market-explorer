# Data Plan

> Feeds the midterm "ER diagram, schema and data plan" (3 pts) and the final "Working with the data" section.
> Estimates are marked *est.*; replace them with measured numbers after each load.

## Sources

| Source | What we take | How we get it |
|---|---|---|
| HMDA public Loan/Application Register (FFIEC/CFPB) | One row per mortgage application, NJ, 2021–2024 **[D3]** | Data Browser CSV download per year, or Snapshot national file filtered to NJ |
| HMDA reporter panel / transmittal sheet | Lender name and type by LEI | FFIEC HMDA Snapshot files |
| U.S. Census county adjacency file | Which counties border which | census.gov reference files |
| Census TIGER/Line cartographic boundaries | County and tract shapes for the map | census.gov (GeoJSON after conversion; served as static files, not stored in Postgres) |

All primary data is **real, public data**. The only generated data is demo user accounts and their saved investigations/watchlists.

## Per-table row estimates

| Table | Rows (est.) | Source | Written by |
|---|---|---|---|
| `application` | **1,729,199 loaded** (1,537,805 if purchased loans are dropped, D16) | HMDA LAR | Admin import script |
| `application_denial_reason` | **319,827 loaded** | HMDA LAR | Admin import script |
| `market_summary` | **113,782 loaded** | Derived from `application` | Admin import script |
| `lender` | **1,299 loaded** | Reporter panel | Admin import script |
| `county` | 21 NJ + bordering out-of-state counties | Census | Seed script |
| `county_adjacency` | **116 loaded** | Census | Seed script |
| `census_tract` | **8,464 loaded** | HMDA census fields | Admin import script |
| lookup tables | 5–20 each | HMDA data dictionary | Seed script |
| `data_release` | 4 (one per year) | Import log | Admin |
| `app_user` | demo accounts + generated users, ~1k *est.* | Generated | Users (sign-up), Admin |
| `saved_investigation` | ~5k *est.* generated with skew | Users / generator | Owner user |
| `watchlist_item` | ~3k *est.* generated with skew | Users / generator | Owner user |

## Cleaning rules (draft)
- Keep all `action_taken` values (1–8): denial and withdrawal analysis needs them. **[D3]**
- Drop rows with missing county or LEI.
- `loan_amount` kept as reported (public file uses $10k band midpoints; verify on first load).
- Pricing fields (`interest_rate`, `rate_spread`, `total_loan_costs`, `discount_points`): HMDA reports "NA"/"Exempt" for non-originated loans and some small lenders → store NULL.
- `conforming_loan_limit`: C → true, NC → false, U/NA → NULL.
- Denial reasons 1–4 → rows in `application_denial_reason`, skipping code 10 (not applicable).
- Record rows read vs. loaded, and why rows were dropped, in `data_release` and in this file.

## Size budget
- Target: whole database comfortably inside the host's free tier **[D5]**.
- `application` row ≈ 24-byte tuple header + ~65 bytes of data → roughly 90–110 bytes/row → **~160–200 MB for 1.74M rows before indexes** *est.*
- Measure after the first load with `pg_total_relation_size` / `pg_indexes_size` and record below.

## Measured (fill in after each load)

| Table | Rows | Table size | Index size | Load time |
|---|---|---|---|---|
| application | 1,729,199 | 213 MB | 37 MB (PK only) | 74 s for 4 years (30 / 17 / 13 / 14 s) |
| application_denial_reason | 319,827 | 14 MB | 13 MB | (included above) |
| market_summary | 113,782 | 10 MB | 8.6 MB | 6 s |
| census_tract | 8,464 | 0.6 MB | 0.4 MB | |
| lender | 1,299 | 0.2 MB | 0.1 MB | |
| county_adjacency | 116 | — | — | |
| **Whole database** | | | | **305 MB, 84 s end to end** (2026-10-10, Rohan's Mac, Postgres 16) |

Rows dropped at load: 10,660 of 1,739,859 (0.6%): 9,726 with a missing or non-NJ county, 934 with no loan amount. Details and what this means for each decision: [`data-findings.md`](data-findings.md).

## Access rules

Enforced in the application (server-side checks on every route, not just hidden buttons), by the final.

| Data | Guest | Homebuyer | Analyst | Admin |
|---|---|---|---|---|
| HMDA data (`application`, summaries, lenders, counties) | Read **[D2]** | Read | Read | Read; write only through import |
| Investigation results | Run Inv. 1 **[D2]** | Run Inv. 1 | Run all | Run all |
| `saved_investigation` | — | Read/write **own** | Read/write **own** | Read all |
| `watchlist_item` | — | — | Read/write **own** | Read all |
| `data_release` (import a year, rebuild summaries) | — | — | Read (see release dates) | Read/write |
| `app_user` | Sign up | Edit own profile | Edit own profile | Read all; change roles |
