# ER Diagram (draft)

Generated from [`../db/schema.sql`](../db/schema.sql). Keep the two in sync. Lookup tables (`*_code`) are omitted for readability. GitHub renders Mermaid automatically; to export an image use [mermaid.live](https://mermaid.live).

Updated 10/10 for the decisions in [`open-decisions.md`](open-decisions.md): narrow `application` with integer `lender_id` and smallint `county_id` (D10), `lender_successor` (D17), no admin role (D2). The user tables stay empty while Homebuyer and Analyst are guests (D2).

```mermaid
erDiagram
    COUNTY ||--o{ COUNTY_ADJACENCY : "has neighbors"
    COUNTY ||--o{ CENSUS_TRACT : contains
    COUNTY ||--o{ APPLICATION : "located in"
    LENDER ||--o{ APPLICATION : receives
    LENDER ||--o| LENDER_SUCCESSOR : "merged into"
    APPLICATION ||--o{ APPLICATION_DENIAL_REASON : "denied for"
    COUNTY ||--o{ MARKET_SUMMARY : summarizes
    LENDER ||--o{ MARKET_SUMMARY : summarizes
    APP_USER ||--o{ SAVED_INVESTIGATION : saves
    APP_USER ||--o{ WATCHLIST_ITEM : watches
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
    }
    DATA_RELEASE {
        serial release_id PK
        smallint year
        char2 state_code
        int rows_read
        int rows_loaded
        jsonb rows_dropped
        numeric load_seconds
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
    }
    APP_USER {
        serial user_id PK
        text email
        text password_hash
        text role "homebuyer or analyst"
    }
    SAVED_INVESTIGATION {
        serial saved_id PK
        int user_id FK
        text investigation
        jsonb params
    }
    WATCHLIST_ITEM {
        int user_id FK
        smallint county_id FK
        int lender_id FK
        int last_seen_release FK
    }
```
