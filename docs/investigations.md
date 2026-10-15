# Guided Investigations — Research and Recommendation

> Prepared 2026-10-10 for the team meeting (decision **D1** in [`open-decisions.md`](open-decisions.md)).
> Goal: choose investigations that answer a question someone actually has, that public HMDA tools don't already answer, and that produce heavy, real queries for our "behavior at scale" grade.

---

## 1. Summary

**Recommended set:** three core investigations plus one stretch. Together they cover all five of the professor's examples, and the first adds something no public HMDA tool offers (comparing what similar borrowers actually paid, by lender).

| # | Investigation | User | Question it answers | Professor's examples covered |
|---|---|---|---|---|
| 1 | **A loan like mine** | Homebuyer | "Where in NJ is a loan like mine normal, is it a jumbo loan there, who makes loans like it, and what did people pay?" | #1, #5, + pricing |
| 2 | **Market vs. its neighbors** | Analyst | "Why does this county look so different from the counties next to it?" | #2, #4, #5 |
| 3 | **What changed?** | Analyst | "What moved unusually in this county or for this lender since last year?" | #3 |
| S | **Neighborhood lending gap** (stretch) | Analyst | "Does this lender reach majority-minority neighborhoods as often as its peers do?" | new |

Why three and not five: three investigations built properly (guided steps, benchmark, written finding, saved/watchable) beat five shallow pages, and the midterm needs mockups for each one we claim.

---

## 2. How we judged them

Each candidate was scored 1–3 on five criteria:

- **Real user need:** is there a person who has this question today?
- **Not already solved:** can the HMDA Data Browser, FFIEC reports or Zillow-type sites already answer it in a few clicks?
- **Data supports it:** can the public HMDA fields actually answer it honestly?
- **Database substance:** does it produce heavy, varied queries (joins, window functions, percentiles, range filters) we can measure at 10k/100k/1M rows?
- **Demo story:** can we show it in under two minutes in the pitch and have it land?

| Candidate | Need | Not solved | Data | DB | Demo | Total |
|---|---|---|---|---|---|---|
| Target loan size: where is it common (prof #1) | 3 | 2 | 3 | 2 | 3 | 13 |
| **+ pricing: what did similar loans cost, by lender (new)** | 3 | 3 | 2 | 3 | 3 | **14** |
| Neighboring counties comparison (prof #2) | 2 | 3 | 3 | 3 | 2 | 13 |
| Unusual year-over-year changes (prof #3) | 2 | 3 | 3 | 3 | 3 | **14** |
| High-denial markets + reasons (prof #4) | 2 | 2 | 3 | 2 | 2 | 11 |
| Lenders within one market (prof #5) | 2 | 1 | 3 | 2 | 2 | 10 |
| Neighborhood lending gap / redlining peer test (new) | 2 | 3 | 3 | 3 | 3 | 14 |
| Affordability stretch: DTI trends (new) | 2 | 2 | 2 | 2 | 1 | 9 |

Prof #4 and #5 score lower **on their own** (the Data Browser can already show denial reasons and lender lists for one county), but they become strong **inside** a comparison, which is why they're folded into Investigation 2 rather than dropped.

---

## 3. Context that makes these relevant (the "why now" for the pitch)

- **The market collapsed and reshaped between 2021 and 2023.** CFPB: applications fell 30% and originations 32% from 2022 to 2023; single-family refinancing fell 64%. Our 2021–2024 window captures the whole swing. [CFPB, Dec 2024]
- **Who lends changed.** Independent mortgage companies (nonbanks) made nearly 62% of home purchase loans in 2023 [CFPB]. Wells Fargo, historically one of the largest lenders, announced in Jan 2023 it was exiting correspondent lending and shrinking its mortgage business [Benzinga]. Exactly the kind of lender exit "What changed?" should surface.
- **Price differences between lenders got much bigger.** Freddie Mac found rate dispersion across lenders averaged under 0.2 points in 2010–2021 but about 0.5 points in late 2022; getting four quotes could save over $1,200 a year [Freddie Mac, Feb 2023]. The CFPB has found nearly half of borrowers don't shop at all. Over 56% of 2023 originations paid discount points, with median total loan costs of about $6,700 on purchase loans [CFPB].
- **Debt-to-income became the denial story.** By mid-2022, DTI was cited in over 45% of denials for Black and Hispanic applicants, the highest since 2018 [CFPB, Nov 2022].
- **NJ has a live fair-lending case in our own data window.** In 2022 the DOJ settled with Lakeland Bank for redlining majority-Black and Hispanic neighborhoods in the Newark area (Essex, Morris, Somerset, Sussex, Union counties), the third-largest redlining settlement in DOJ history (at least $12M loan subsidy fund + $1.15M outreach). DOJ's evidence was HMDA: Lakeland generated far fewer applications from those tracts than its peer lenders did [Consumer Finance Monitor].
- **NJ's jumbo line differs by county.** In 2025 the conforming limit is $1,209,750 in 12 northern/central counties (Bergen, Essex, Hudson, Hunterdon, Middlesex, Monmouth, Morris, Ocean, Passaic, Somerset, Sussex, Union) and $806,500 in the other nine [Bankrate]. An $850k loan is a jumbo loan in Camden and a conforming loan in Bergen, and HMDA marks this on every row (`conforming_loan_limit`).

---

## 4. The investigations in detail

### Investigation 1 — A loan like mine (Homebuyer)

**The person:** a first-time buyer pre-approved for about $450k, flexible on where in NJ to buy. Today they'd use Zillow (starts from a house, not a loan) or the Data Browser (they'd have to know to filter by loan amount band, purpose, occupancy, then compare 21 counties themselves).

**Guided steps:**
1. **Describe your loan:** amount, purchase or refinance, loan type (conventional / FHA / VA), owner-occupied.
2. **Map:** NJ counties (drill into census tracts) shaded by *how common loans like yours are* compared with the statewide share, plus approval rate for loans like yours. Counties where your amount crosses the conforming limit are flagged.
3. **Pick a market → who makes loans like yours there:** lenders ranked by number of similar originated loans, with their approval rate on similar applications.
4. **What did similar borrowers pay:** for similar originated loans (same year, product, term, amount band), each lender's median interest rate, rate spread, total loan costs and discount points, versus the market median.
5. **Save** the search (requires sign-in), compare up to three markets side by side.

**Example findings (real 2024 numbers, see [`data-findings.md`](data-findings.md)):**
- "Purchase loans between $400k and $500k make up 26% of home purchases in Middlesex County, versus 18% statewide (1.5×)."
- "In Cape May, 24% of purchase loans are jumbo, mostly second homes at the shore."
- "Among the four lenders that made 30+ loans like yours in Middlesex, median rates ran from 6.50% to 6.88%, and median total loan costs from $6,755 to $11,175."

**Data used:** `loan_amount`, `loan_purpose`, `loan_type`, `occupancy_type`, `action_taken`, `county_code`, `census_tract`, `conforming_loan_limit`, `lei`, `interest_rate`, `rate_spread`, `total_loan_costs`, `discount_points`, `loan_term`.

**Honest caveats (put them in the UI):**
- HMDA has no credit score, so "what people paid" describes **similar loans**, not a quote the user would get. We compare lenders on comparable loans only and show the count behind every number.
- Public HMDA loan amounts are reported as $10,000 band midpoints (confirmed on first load), so "similar" means an amount band, not an exact figure.
- Only show a lender's pricing when it has at least N similar loans in that market. The data says N = 30 is too strict; see D18.

**Database substance:** range predicates on `loan_amount` combined with county/year/purpose filters (composite vs. partial indexes, real `EXPLAIN` story); `percentile_cont` medians grouped by lender (expensive at 1M rows → candidate for the precomputed summary table); tract-level map aggregation.

---

### Investigation 2 — Market vs. its neighbors (Analyst)

**The person:** a housing researcher or local journalist asking why Essex and Morris, which border each other, look so different. The Data Browser shows one county at a time; comparing adjacent counties means pulling several reports and lining them up by hand.

**Guided steps:**
1. **Pick a county** (or click it on the map). Its neighbors come from the Census county adjacency file.
2. **Gap scan:** the app computes the county vs. each neighbor across a fixed set of measures (denial rate, FHA share, median loan, refi share, nonbank share, lender concentration, withdrawal rate) and **ranks the biggest gaps first**.
3. **Drill into a gap:**
   - *Denial gap* → reported denial reasons here vs. neighbors vs. state (DTI, credit history, collateral, incomplete application...), with a minimum-volume rule so tiny markets don't dominate. (Prof #4.)
   - *Lender gap* → the lenders active on both sides of the border: same lender, different behavior? Lenders present in one county but not the other. (Prof #5.)
4. **Save** the comparison; add counties to a watchlist.

**Example findings (real 2024 numbers, see [`data-findings.md`](data-findings.md)):**
- "Passaic denies 13.2% of home purchase applications, half again as many as neighboring Morris (8.7%)."
- "FHA loans are 32.8% of purchase applications in Cumberland, vs. 3.8% in neighboring Cape May."
- "Bank of America denies 35.8% of decided applications in Morris but 64.9% in Passaic." (needs a per-purpose control before we show it, D19)

**Data used:** `county_code`, all outcome fields, `denial_reason_1..4`, `loan_type`, `lei`, lender type (from reporter panel), adjacency file.

**Database substance:** self-join through `county_adjacency`; conditional aggregation across many measures in one pass; denial reasons as a separate table vs. four columns (our graded design alternative); concentration index (HHI) with window functions.

---

### Investigation 3 — What changed? (Analyst, watchlist-driven)

**The person:** a lender's market analyst or a researcher watching a set of counties. Each September a new HMDA year drops; today they'd re-download everything and diff it themselves.

**Guided steps:**
1. **Pick a county or a lender** (or open your watchlist), and two years (default: latest vs. prior).
2. **Ranked list of unusual shifts:** each measure's year-over-year change is compared with how much that measure normally moves across all NJ counties (a z-score), so a 10-point drop that's normal in 2022 isn't flagged but a lender's 70% exit is. Types of shifts:
   - a lender entering or leaving the market (or its share doubling/halving)
   - a jump in denial rate or a change in the top denial reason
   - a change in product mix (FHA share, refi share, jumbo share)
   - loan-size distribution shifting up or down
3. **Click a shift → its context:** the 2021–2024 trend for that measure, plus which lenders drove it.
4. **Watchlist alerts:** when the admin imports a new HMDA year, each analyst's watched counties/lenders get a "new changes" badge.

**Example findings (real numbers, see [`data-findings.md`](data-findings.md)):**
- "Refinance applications in Morris County fell 88% from 2021 to 2023, the steepest drop in NJ (statewide: −84%)."
- "Wells Fargo made 14,713 NJ loans in 2021 and 1,656 in 2024 (−89%), while TD Bank and Citizens held steady."
- "Warren is the only county whose denial rate rose notably from 2023 to 2024 (+1.9 points, z = 3.1)."

**Data used:** everything aggregated by `(year, county, lei)`; lender type.

**Database substance:** year-over-year comparisons via `LAG()` window functions; the precomputed `market_summary` table vs. on-the-fly aggregation (the cleanest before/after timing story we'll have); the admin's new-year import is our real "process writing data", with its row counts and load times logged.

---

### Stretch — Neighborhood lending gap (Analyst)

**The person:** a community group, a journalist, or a bank's compliance analyst asking whether a lender serves majority-minority neighborhoods as much as its competitors.

**Steps:** pick a lender and a market → the lender's share of applications from majority-minority tracts (and low/moderate-income tracts) vs. the same share for all other lenders in that market → year trend → map of tracts where peers are active and the lender is not.

**Why it's compelling:** this is a simplified version of the peer-comparison method behind the 2022 Lakeland Bank case in our own market and years. The fields are already on every HMDA row (`census_tract`, `tract_minority_population_percent`, `tract_to_msa_income_percentage`).

**Verified on our data (10/10):** in the Newark-area counties, 8.1% of Lakeland's 2021 applications came from majority-minority tracts, vs. 29.8% for other lenders (ratio 0.27). The ratio rose to 0.47 in 2022 and 1.10 in 2023, after the settlement.

**Framing caveat:** present it as "how a lender's reach compares with peers", not as a finding of discrimination. Real fair-lending analysis controls for branch locations, products and more.

**Database substance:** tract-level joins and grouping, peer aggregates that exclude the lender itself (anti-join or windowed totals).

---

## 5. What every investigation shares (our differentiator, built once)

1. **A question-first entry page:** "What do you want to find out?" with the three investigations as cards, not a filter sidebar.
2. **Always a benchmark:** state, neighbors, prior year or peers.
3. **A finding sentence** at the top of every result, generated from a template and query results, with the underlying numbers one click away.
4. **Minimum-volume rules** so a county with 40 loans never "wins" a ranking.
5. **Save / watch** for signed-in users, which gives us the write path and the per-role access rules.

## 6. Data we'll need beyond the HMDA rows

| Data | Source | Why |
|---|---|---|
| HMDA public LAR, NJ, 2021–2024 | FFIEC HMDA Data Browser / Snapshot files | Everything |
| Lender names and type | HMDA reporter panel / transmittal sheet (by LEI) | HMDA rows only carry the LEI |
| County adjacency | U.S. Census Bureau county adjacency file | Investigation 2 neighbors |
| County and tract boundaries (GeoJSON) | Census TIGER/Line cartographic boundary files | Map |
| Conforming loan limits | Already in HMDA (`conforming_loan_limit` per row); FHFA table for display | Investigation 1 |

## 7. Suggested midterm scope

- **Mockups:** all three core investigations, plus the admin import screen and the analyst watchlist (covers one screen per user type).
- **Prototype:** Investigation 1 on a 100k-row sample, by 10/16.
- **Pitch:** open with the homebuyer story (Investigation 1), then show "What changed?" with the 2021 → 2023 collapse, and close with what we expect to be hard (medians at 1M rows, map aggregation speed, pricing comparability).

## Sources
- [CFPB: Significant drop in 2023 mortgage applications and originations (Dec 2024)](https://www.consumerfinance.gov/about-us/newsroom/cfpb-report-finds-significant-drop-in-annual-mortgage-applications-and-originations-in-2023)
- [CFPB: Higher interest rates leading to higher debt burdens for mortgage borrowers (Nov 2022)](https://www.consumerfinance.gov/about-us/blog/higher-interest-rates-leading-to-higher-debt-burdens-for-mortgage-borrowers)
- [CFPB: Nearly half of borrowers do not shop for a mortgage](https://www.consumerfinance.gov/about-us/newsroom/cfpb-report-finds-nearly-half-of-borrowers-do-not-shop-for-a-mortgage)
- [Freddie Mac: When rates are higher, borrowers who shop around save more (Feb 2023)](https://www.freddiemac.com/research/insight/20230216-when-rates-are-higher-borrowers-who-shop-around-save)
- [Consumer Finance Monitor: DOJ announces settlement of redlining lawsuit (Lakeland Bank, Oct 2022)](https://www.consumerfinancemonitor.com/2022/10/03/doj-announces-settlement-of-redlining-lawsuit/)
- [Benzinga: Wells Fargo steps back from mortgage business (Jan 2023)](https://www.benzinga.com/news/23/01/30363151/wells-fargo-steps-back-from-mortgage-business-whats-going-on)
- [Bankrate: 2025 New Jersey conforming loan limits by county](https://www.bankrate.com/mortgages/new-jersey-jumbo-loan-limits-by-county/)
- [FFIEC: HMDA public LAR data fields](https://ffiec.cfpb.gov/documentation/publications/loan-level-datasets/lar-data-fields)
- [U.S. Census Bureau: County adjacency file](https://www.census.gov/geographies/reference-files/time-series/geo/county-adjacency.html)

_Example findings were updated with real numbers from the first full load on 2026-10-10 (see [`data-findings.md`](data-findings.md)). Numbers in section 3 are from the cited sources._
