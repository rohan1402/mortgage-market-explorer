# What the Data Told Us — First Full Load (2026-10-10)

> NJ HMDA 2021–2024 loaded with `etl/load.sh` into local Postgres 16. Every number below comes from
> [`analysis/investigation_checks.sql`](../analysis/investigation_checks.sql) (output: `analysis/results.txt`) or
> [`analysis/followup_checks.sql`](../analysis/followup_checks.sql) (output: `analysis/followup_results.txt`).
> Decisions these findings raise are in [`open-decisions.md`](open-decisions.md) under **"Raised by the data"** (D16–D21).

## 1. The load

> **Rebuilt 10/10 after D10, D16 and D17:** `application` now has **1,537,805 rows** (purchased loans dropped) at 94 bytes/row, 138 MB, and the database is **211 MB**. Both analysis scripts were re-run on the new schema and every finding in §2–§4 came out the same. The table below describes the first load.


| | Value |
|---|---|
| Rows downloaded | 1,739,859 (2021: 707,685 · 2022: 414,459 · 2023: 293,775 · 2024: 323,940) |
| Rows loaded into `application` | **1,729,199** (2021: 705,396 · 2022: 409,750 · 2023: 291,974 · 2024: 322,079) |
| Rows dropped | 10,660 (0.6%): 9,726 with a missing or non-NJ county, 934 with no loan amount |
| Load time, empty DB → done | **84 s** on Rohan's Mac (30 / 17 / 13 / 14 s per year + 6 s summary table) |
| `application` size | 213 MB table + 37 MB primary-key index = 251 MB · **129 bytes/row** |
| Whole database | **305 MB**, before any secondary indexes |
| Other tables | `application_denial_reason` 319,827 rows (26 MB) · `market_summary` 113,782 (18 MB) · `census_tract` 8,464 · `lender` 1,299 (all named) · `county_adjacency` 116 |

**1M-row check (decision D3):**

| Scope | Rows | ≥ 1M? |
|---|---|---|
| All rows, 2021–2024 | 1,729,199 | ✅ |
| Excluding purchased loans (action 6) | 1,537,805 | ✅ |
| Applications only (actions 1–5) | 1,535,579 | ✅ |
| 2022–2024, all rows | 1,023,803 | ⚠️ barely |
| 2022–2024, excluding purchased loans | 911,267 | ❌ |

→ **2021 is needed.** Without it we're under 1M as soon as purchased loans are excluded.

**Size check (decision D5):** 305 MB is already over the assignment's ~256 MB guideline and Render's free Postgres, before indexes. A narrower `application` table (integer lender id instead of the 20-character LEI, smallint county, no `release_id`) measured **164 MB vs. 213 MB (99 bytes/row, −23%)**. Neon or Supabase (~0.5 GB free) fit either way.

## 2. The market story (for the pitch)

- **Refinancing collapsed:** NJ refinance applications fell **84%** from 2021 to 2023 (383,860 → 61,092). Purchase applications fell 36%. "Other purpose" loans (mostly home equity) rose 47%.
- **County level:** refi applications fell 72% (Cumberland) to **88% (Morris, Somerset, Bergen)**.
- **Big lenders shrank, but not equally (2021 → 2024 originations):**
  - **Wells Fargo: 14,713 → 1,656 (−89%).**
  - Better Mortgage −96%. Rocket −71%. loanDepot −81%.
  - TD Bank +5.5% and Citizens +3.4% held steady.
  - Caliber and Home Point disappeared entirely (see D17).
- **Lakeland Bank, the 2022 DOJ redlining case, is visible in the data:**
  - In the Newark-area counties named in the settlement, Lakeland's share of applications from majority-minority tracts compared with other lenders' share was:

    | Year | Lakeland | Other lenders | Ratio |
    |---|---|---|---|
    | 2021 | 8.1% | 29.8% | 0.27 |
    | 2022 (settlement in Sept) | 19.3% | 40.9% | 0.47 |
    | 2023 | 45.6% | 41.4% | 1.10 |
  - Lakeland then has zero 2024 rows because it **merged into Provident Bank in May 2024**. This is a merger, not an exit (D17).

## 3. Per investigation

### Investigation 1 — A loan like mine ✅ works, with a looser "similar loan" rule
- **Where is my loan size normal:**
  - In 2024, 26.4% of Middlesex home-purchase loans were $400–500k, versus 18.0% statewide (1.47×). Passaic was 25.8% and Union 23.0%.
  - At the low end, Salem was 3.9% and Cumberland 6.1%. Clear, real geographic signal.
- **Jumbo:**
  - HMDA's conforming flag tracks the two NJ limit tiers. Northern counties show conforming loans up to $1.1M+, southern ones up to about $765k.
  - **Cape May is the outlier: 24% of 2024 purchase loans are jumbo**, mostly second homes at the shore (352 of 471 jumbo loans), with a median of $1.17M.
- **What did similar borrowers pay:** the data supports it, but the strict rule we drafted is too strict.

  | "Similar loan" rule | Counties where ≥ 3 lenders are comparable |
  |---|---|
  | 2024, $400–500k, ≥ 30 loans per lender | 7 of 21 |
  | 2024, $400–500k, ≥ 20 | 13 |
  | 2024, $350–550k, ≥ 20 | 17 |
  | 2023–24 pooled, $350–550k, ≥ 20 | 18 |

  - Interest rate is reported on 97–99% of originations. Total loan costs are reported on only about 67% in 2023–24.
  - **Example, Middlesex, 2024, 30-yr conventional purchase, $400–500k:**

    | Lender | Similar loans | Median rate | Median total costs | Average points |
    |---|---|---|---|---|
    | Rocket | 67 | 6.50% | $6,755 | $2,273 |
    | UWM | 110 | 6.62% | $11,175 | $884 |
    | CrossCountry | 89 | 6.63% | $7,954 | $2,214 |
    | Movement | 34 | 6.88% (highest) | $10,057 | $3,767 (most) |

    Rates and costs must be shown together, since points buy rates down.
  - **Biggest spread:** Ocean County. Lender median rates ran 6.13%–7.00% and median costs $4.8k–$9.4k.

### Investigation 2 — Market vs. its neighbors ✅ works, but compare by loan purpose
- **Denial rates depend mostly on loan purpose:**

  | Purpose (2024) | Denial rate |
  |---|---|
  | Home purchase | 11.3% |
  | Refinance | 25% |
  | Cash-out | 33% |
  | Home improvement | 40% |
  | Other | 45% |

  A county's all-purpose denial rate mostly reflects its purpose mix, so comparisons must be per purpose (D19).
- **Purchase-only gaps are still real:**
  - Morris 8.7% vs. neighboring Passaic 13.2%.
  - Essex has the highest purchase denial rate at 14.8%. Gloucester has the lowest at 8.3%.
- **FHA share of purchase applications:** Cape May 3.8% vs. neighboring Cumberland 32.8%. Morris 8.1% vs. Passaic 21.2%.
- **Same lender, different county:**
  - Bank of America denies 35.8% of decided applications in Morris vs. 64.9% in Passaic.
  - loanDepot denies 7.1% in Hudson vs. 30.5% in Union.
  - These are all-purpose rates and still need a per-purpose control before we present them.
- **Denial *reasons* barely differ by county:**
  - In the three highest-denial counties, DTI is cited in 41–44% of denials vs. 40.9% statewide.
  - Reasons differ by purpose much more: credit history is cited in 36% of home-improvement denials vs. 16% of purchase denials.
  - → Professor's example #4 is weak as a standalone county investigation. It works as a drill-down inside Investigation 2 (D20).

### Investigation 3 — What changed? ✅ strongest stories, needs merger handling
- **Lender exits:** the 2023 → 2024 list is dominated by Lakeland Bank in 10 counties. That's the Provident merger, not a real exit.
- **Entries:** Affordable Mortgage Advisors entered Atlantic County (0 → 145 loans) and Skyrock entered Ocean (0 → 102).
- **The z-score flag works:** Warren is the only county whose denial rate rose notably from 2023 to 2024 (+1.9 points, z = 3.1) while most counties fell.

### Stretch — Neighborhood lending gap ✅ most compelling result so far
- It reproduces the Lakeland pattern from public data and shows it closing after the settlement (table above).
- **Caveat:** other lenders also score low for business-model reasons. Morgan Stanley Private Bank (ratio 0.13) serves wealthy clients. That's exactly why we present this as a comparison with context, not an accusation.

## 4. Data quality notes (for "Working with the data")
- Loan amounts are $10k band midpoints (e.g., 455000), confirmed.
- The total-cost field is missing for about a third of 2023–24 originations. Pricing views must show the count behind every median.
- A few loans under the baseline limit are flagged non-conforming (21 in Cape May, mostly second liens). Minor.
- `discount_points` is blank when no points were paid. Treat NULL as $0 for averages, as `followup_checks.sql` does.
- Lender identity changes over time through mergers (D17).
