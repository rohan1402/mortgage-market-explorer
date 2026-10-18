# ER Diagram

Hand-checked against [`../db/schema.sql`](../db/schema.sql) on 10/17. Keep the two in sync: if `schema.sql` changes, change this file in the same PR.

The midterm rubric asks for "key fields, types and keys for **every** table", so this diagram now includes the lookup tables and every column. GitHub renders Mermaid automatically; to export an image use [mermaid.live](https://mermaid.live).

Reading the diagram:
- `||--o{` one-to-many (a county has many applications). `||--o|` one-to-zero-or-one (a lender has at most one successor).
- Solid lines are foreign keys. Dotted lines mean "derived from" (`market_summary` is rebuilt from `application` at each import, D9).
- PK primary key, FK foreign key, UK unique. `char5` means `char(5)`.

```mermaid
erDiagram
    %% HMDA data (read-only for users; written by etl/load.sh)
    COUNTY ||--o{ APPLICATION : "located in"
    LENDER ||--o{ APPLICATION : "received"
    APPLICATION ||--o{ APPLICATION_DENIAL_REASON : "denied for"
    COUNTY ||--o{ COUNTY_ADJACENCY : "borders"
    COUNTY ||--o{ CENSUS_TRACT : "contains"
    LENDER ||--o| LENDER_SUCCESSOR : "merged into"
    LENDER ||--o{ LENDER_SUCCESSOR : "successor of"
    COUNTY ||--o{ MARKET_SUMMARY : "summarized in"
    LENDER ||--o{ MARKET_SUMMARY : "summarized in"
    MARKET_SUMMARY ||..|{ APPLICATION : "rebuilt from"

    %% Lookup tables (HMDA code lists)
    ACTION_TAKEN_CODE ||--o{ APPLICATION : "labels"
    LOAN_TYPE_CODE ||--o{ APPLICATION : "labels"
    LOAN_PURPOSE_CODE ||--o{ APPLICATION : "labels"
    OCCUPANCY_CODE ||--o{ APPLICATION : "labels"
    DTI_BUCKET_CODE ||--o{ APPLICATION : "labels"
    DENIAL_REASON_CODE ||--o{ APPLICATION_DENIAL_REASON : "labels"

    %% User data (empty while users are guests, D2)
    APP_USER ||--o{ SAVED_INVESTIGATION : "saves"
    APP_USER ||--o{ WATCHLIST_ITEM : "watches"
    COUNTY ||--o{ WATCHLIST_ITEM : "watched as"
    LENDER ||--o{ WATCHLIST_ITEM : "watched as"
    DATA_RELEASE ||--o{ WATCHLIST_ITEM : "last seen"

    APPLICATION {
        serial application_id PK
        int lender_id FK
        bigint tract_fips
        int loan_amount
        int property_value
        int income_k
        int total_loan_costs
        int discount_points
        smallint year
        smallint county_id FK
        smallint action_taken FK
        smallint loan_type FK
        smallint loan_purpose FK
        smallint lien_status
        smallint occupancy FK
        smallint dti_bucket FK
        smallint loan_term
        bool conforming
        numeric interest_rate
        numeric rate_spread
    }
    APPLICATION_DENIAL_REASON {
        int application_id PK,FK
        smallint reason PK,FK
    }
    LENDER {
        serial lender_id PK
        char20 lei UK
        text name
        smallint lender_type
    }
    LENDER_SUCCESSOR {
        int lender_id PK,FK
        int successor_lender_id FK
        date effective_date
        text event
        text source
    }
    COUNTY {
        smallint county_id PK
        char5 county_fips UK
        text name
        char2 state_code
    }
    COUNTY_ADJACENCY {
        char5 county_fips PK,FK
        char5 neighbor_fips PK
    }
    CENSUS_TRACT {
        bigint tract_fips PK
        smallint year PK
        smallint county_id FK
        numeric minority_pct
        smallint tract_to_msa_income_pct
        int owner_occupied_units
    }
    MARKET_SUMMARY {
        smallint year PK
        smallint county_id PK,FK
        int lender_id PK,FK
        smallint loan_purpose PK
        smallint loan_type PK
        int applications
        int originations
        int denials
        int withdrawals
        bigint total_amount
    }
    DATA_RELEASE {
        serial release_id PK
        smallint year UK
        char2 state_code UK
        text source_url
        int rows_read
        int rows_loaded
        jsonb rows_dropped
        numeric load_seconds
        timestamptz loaded_at
    }
    ACTION_TAKEN_CODE {
        smallint code PK
        text label
    }
    LOAN_TYPE_CODE {
        smallint code PK
        text label
    }
    LOAN_PURPOSE_CODE {
        smallint code PK
        text label
    }
    OCCUPANCY_CODE {
        smallint code PK
        text label
    }
    DTI_BUCKET_CODE {
        smallint code PK
        text label
    }
    DENIAL_REASON_CODE {
        smallint code PK
        text label
    }
    APP_USER {
        serial user_id PK
        text email UK
        text password_hash
        text role
        timestamptz created_at
    }
    SAVED_INVESTIGATION {
        serial saved_id PK
        int user_id FK
        text investigation
        text title
        jsonb params
        timestamptz created_at
        timestamptz updated_at
    }
    WATCHLIST_ITEM {
        int user_id FK,UK
        smallint county_id FK,UK
        int lender_id FK,UK
        text note
        int last_seen_release FK
        timestamptz created_at
    }
```

## Tables at a glance

Row counts are measured from the 10/10 full load (details and sources in [`data-plan.md`](data-plan.md)).

| Group | Table | Rows | Primary key | Notes |
|---|---|---|---|---|
| HMDA | `application` | 1,537,805 | `application_id` | The 1M+ table. Narrow by design (D10): codes, not text. |
| HMDA | `application_denial_reason` | 319,827 | (`application_id`, `reason`) | Up to 4 reasons per denied application. |
| HMDA | `market_summary` | 107,327 | (`year`, `county_id`, `lender_id`, `loan_purpose`, `loan_type`) | Rebuilt from `application` at each import (D9). |
| Reference | `lender` | 1,269 | `lender_id` | LEI kept once here; `application` stores the 4-byte id. |
| Reference | `lender_successor` | 1 | `lender_id` | Mergers, so "What changed?" doesn't report them as exits (D17). |
| Reference | `county` | 21 | `county_id` | `county_fips` is unique too; the 2-byte id goes in `application`. |
| Reference | `county_adjacency` | 116 | (`county_fips`, `neighbor_fips`) | Neighbors can be in NY, PA or DE, so `neighbor_fips` has no FK. |
| Reference | `census_tract` | 8,464 | (`tract_fips`, `year`) | Tract attributes change with census vintage, so year is part of the key. |
| Reference | `data_release` | 4 | `release_id` | One row per yearly import, with rows read, loaded and dropped. |
| Lookup | `action_taken_code` | 8 | `code` | Code 6 (purchased loan) is dropped at load (D16). |
| Lookup | `loan_type_code` | 4 | `code` | |
| Lookup | `loan_purpose_code` | 6 | `code` | |
| Lookup | `occupancy_code` | 3 | `code` | |
| Lookup | `denial_reason_code` | 9 | `code` | |
| Lookup | `dti_bucket_code` | 19 | `code` | HMDA reports DTI in bins. |
| User | `app_user` | 0 for now | `user_id` | Guests only until accounts are added (D2). |
| User | `saved_investigation` | 0 for now | `saved_id` | |
| User | `watchlist_item` | 0 for now | none (unique on `user_id`, `county_id`, `lender_id`) | Exactly one of `county_id` / `lender_id` is set (CHECK). |

## Where each investigation reads

| Investigation | Main tables | Why |
|---|---|---|
| 1. A loan like mine | `application`, `county`, `lender` | Range filter on `loan_amount`, then lender medians of rate and costs (needs the raw rows). |
| 2. Market vs. its neighbors | `county_adjacency`, `market_summary`, `application_denial_reason`, `denial_reason_code` | Neighbors by lookup; counts from the summary; denial reasons per loan purpose (D19). |
| 3. What changed? | `market_summary`, `lender_successor` | Year-over-year change with `LAG()`; successor table so a merger isn't an exit (D17). |
| Stretch: lending gap | `application`, `census_tract`, `lender` | Share of a lender's loans in majority-minority tracts vs. peers. |
