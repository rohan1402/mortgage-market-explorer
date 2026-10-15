-- Mortgage Market Explorer — PostgreSQL schema
-- Updated 2026-10-10 to match the Decided table in docs/open-decisions.md:
--   D3   NJ 2021–2024, every application whatever its outcome, except purchased loans
--   D16  purchased-loan rows (action 6) are dropped by etl/load.sh
--   D9   precomputed market_summary (graded design alternative)
--   D10  narrow application table: numeric codes, integer lender_id, smallint county_id, no release_id
--   D17  lender_successor, so mergers aren't shown as exits
--   D2   two user types (homebuyer, analyst), guests for now; no admin role (imports run as a script)
-- Still open: D18 (which pricing fields to keep).
--
-- Rebuild from empty:  psql "$DATABASE_URL" -f db/schema.sql   (etl/load.sh does this first)
-- Design rules:
--   * application is the 1M+ row table: keep it narrow, store categories as smallint codes.
--   * Labels live in small lookup tables.
--   * User-created data (accounts, saved investigations, watchlists) is separate from HMDA data.

BEGIN;

DROP SCHEMA IF EXISTS mme CASCADE;
CREATE SCHEMA mme;
SET search_path TO mme;

-- ---------------------------------------------------------------------------
-- Lookup tables (codes from the HMDA public LAR data dictionary)
-- ---------------------------------------------------------------------------
CREATE TABLE action_taken_code   (code smallint PRIMARY KEY, label text NOT NULL); -- 1 originated .. 8 preapproval approved not accepted (6 is dropped at load, D16)
CREATE TABLE loan_type_code      (code smallint PRIMARY KEY, label text NOT NULL); -- 1 conventional, 2 FHA, 3 VA, 4 USDA
CREATE TABLE loan_purpose_code   (code smallint PRIMARY KEY, label text NOT NULL); -- 1 purchase, 2 improvement, 31 refi, 32 cash-out refi, 4 other, 5 NA
CREATE TABLE denial_reason_code  (code smallint PRIMARY KEY, label text NOT NULL); -- 1 DTI, 2 employment, 3 credit history, 4 collateral, ...
CREATE TABLE occupancy_code      (code smallint PRIMARY KEY, label text NOT NULL);
CREATE TABLE dti_bucket_code     (code smallint PRIMARY KEY, label text NOT NULL); -- HMDA reports DTI in bins

-- ---------------------------------------------------------------------------
-- Reference data
-- ---------------------------------------------------------------------------
CREATE TABLE county (
    county_id        smallint     PRIMARY KEY,          -- 2 bytes in application (D10); for NJ, the 3-digit county code (23 = Middlesex)
    county_fips      char(5)      NOT NULL UNIQUE,      -- e.g. '34023'
    name             text         NOT NULL,
    state_code       char(2)      NOT NULL
);

CREATE TABLE county_adjacency (                          -- Census county adjacency file
    county_fips      char(5)      NOT NULL REFERENCES county (county_fips),
    neighbor_fips    char(5)      NOT NULL,              -- may be out of state (NY, PA, DE)
    PRIMARY KEY (county_fips, neighbor_fips)
);

CREATE TABLE census_tract (                              -- tract attributes HMDA appends to each row
    tract_fips                 bigint       NOT NULL,     -- 11-digit tract code stored as a number (34023008100)
    year                       smallint     NOT NULL,     -- tract data changes with census vintage
    county_id                  smallint     NOT NULL REFERENCES county,
    minority_pct               numeric(5,2),
    tract_to_msa_income_pct    smallint,
    owner_occupied_units       integer,
    PRIMARY KEY (tract_fips, year)
);

CREATE TABLE lender (
    lender_id        serial       PRIMARY KEY,           -- 4 bytes in application instead of the 20-character LEI (D10)
    lei              char(20)     NOT NULL UNIQUE,       -- Legal Entity Identifier
    name             text,                               -- from the HMDA filers list
    lender_type      smallint                            -- bank / credit union / independent mortgage co. (D14)
);

-- D17: a lender that stopped reporting because it merged into another one.
-- "What changed?" follows lender_id -> successor_lender_id instead of reporting an exit.
CREATE TABLE lender_successor (
    lender_id            integer      PRIMARY KEY REFERENCES lender,
    successor_lender_id  integer      NOT NULL REFERENCES lender,
    effective_date       date         NOT NULL,
    event                text         NOT NULL,          -- e.g. 'merger'
    source               text         NOT NULL,          -- where we verified it
    CHECK (lender_id <> successor_lender_id)
);

CREATE TABLE data_release (                              -- one row per yearly import (etl/load.sh)
    release_id       serial       PRIMARY KEY,
    year             smallint     NOT NULL,
    state_code       char(2)      NOT NULL,
    source_url       text         NOT NULL,
    rows_read        integer,
    rows_loaded      integer,
    rows_dropped     jsonb,                              -- {"reason": count}, e.g. purchased loans (D16)
    load_seconds     numeric(8,1),
    loaded_at        timestamptz  NOT NULL DEFAULT now(),
    UNIQUE (year, state_code)
);

-- ---------------------------------------------------------------------------
-- Primary table: one row per HMDA application (target >= 1,000,000 rows)
-- Columns are grouped 8-, 4-, 2-, 1-byte, then variable width, so Postgres adds
-- no alignment padding between them (D10).
-- ---------------------------------------------------------------------------
CREATE TABLE application (
    application_id    serial       PRIMARY KEY,          -- assigned by etl/load.sh
    lender_id         integer      NOT NULL REFERENCES lender,
    tract_fips        bigint,                            -- joins census_tract on (tract_fips, year)
    loan_amount       integer      NOT NULL,             -- dollars (public file reports $10k band midpoints)
    property_value    integer,
    income_k          integer,                           -- thousands of dollars
    total_loan_costs  integer,                           -- pricing fields: originated loans only (D18 open)
    discount_points   integer,
    year              smallint     NOT NULL,
    county_id         smallint     NOT NULL REFERENCES county,
    action_taken      smallint     NOT NULL REFERENCES action_taken_code,
    loan_type         smallint     NOT NULL REFERENCES loan_type_code,
    loan_purpose      smallint     NOT NULL REFERENCES loan_purpose_code,
    lien_status       smallint     NOT NULL,
    occupancy         smallint     NOT NULL REFERENCES occupancy_code,
    dti_bucket        smallint     REFERENCES dti_bucket_code,
    loan_term         smallint,                          -- months
    conforming        boolean,                           -- from conforming_loan_limit (C / NC); null = U/NA
    interest_rate     numeric(6,3),
    rate_spread       numeric(6,3)
);

-- Denial reasons: separate table rather than denial_reason_1..4 columns on application.
CREATE TABLE application_denial_reason (
    application_id   integer      NOT NULL REFERENCES application ON DELETE CASCADE,
    reason           smallint     NOT NULL REFERENCES denial_reason_code,
    PRIMARY KEY (application_id, reason)
);

-- Precomputed summary (D9): rebuilt at each import. Denial comparisons read it per loan_purpose (D19).
CREATE TABLE market_summary (
    year              smallint     NOT NULL,
    county_id         smallint     NOT NULL REFERENCES county,
    lender_id         integer      NOT NULL REFERENCES lender,
    loan_purpose      smallint     NOT NULL,
    loan_type         smallint     NOT NULL,
    applications      integer      NOT NULL,
    originations      integer      NOT NULL,
    denials           integer      NOT NULL,
    withdrawals       integer      NOT NULL,
    total_amount      bigint       NOT NULL,
    PRIMARY KEY (year, county_id, lender_id, loan_purpose, loan_type)
);

-- ---------------------------------------------------------------------------
-- Users and user-created data (D2)
-- Homebuyer and Analyst use the site as guests for now, so these tables stay empty
-- until accounts are added (revisit before the final). There is no admin role:
-- the yearly import is etl/load.sh, run by the team.
-- ---------------------------------------------------------------------------
CREATE TABLE app_user (
    user_id          serial       PRIMARY KEY,
    email            text         NOT NULL UNIQUE,
    password_hash    text         NOT NULL,
    role             text         NOT NULL CHECK (role IN ('homebuyer', 'analyst')),
    created_at       timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE saved_investigation (
    saved_id         serial       PRIMARY KEY,
    user_id          integer      NOT NULL REFERENCES app_user ON DELETE CASCADE,
    investigation    text         NOT NULL CHECK (investigation IN ('loan_like_mine', 'market_vs_neighbors', 'what_changed', 'lending_gap')),
    title            text         NOT NULL,
    params           jsonb        NOT NULL,              -- e.g. {"amount": 450000, "purpose": 1, "county": 23}
    created_at       timestamptz  NOT NULL DEFAULT now(),
    updated_at       timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE watchlist_item (
    user_id          integer      NOT NULL REFERENCES app_user ON DELETE CASCADE,
    county_id        smallint     REFERENCES county,
    lender_id        integer      REFERENCES lender,
    note             text,
    last_seen_release integer     REFERENCES data_release, -- drives the "new changes" badge
    created_at       timestamptz  NOT NULL DEFAULT now(),
    CHECK ((county_id IS NULL) <> (lender_id IS NULL)),   -- exactly one of county / lender
    UNIQUE (user_id, county_id, lender_id)
);

-- ---------------------------------------------------------------------------
-- Indexes: deliberately NONE on application yet beyond the PK.
-- Add them one at a time from docs/query-log.md evidence (EXPLAIN ANALYZE before/after).
-- ---------------------------------------------------------------------------

COMMIT;
