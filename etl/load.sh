#!/usr/bin/env bash
# Rebuilds the Mortgage Market Explorer database from empty and loads NJ HMDA data.
#
# Usage:
#   etl/load.sh                      # full load, all years found in data/raw/
#   SAMPLE=0.0065 etl/load.sh        # keep ~0.65% of rows (≈10k) for scale tests
#   SAMPLE=0.065  etl/load.sh        # ≈100k
#
# Needs only bash and psql. Connection comes from DATABASE_URL (default: local db "mme").
# Inputs (data/raw/, git-ignored; see etl/README.md for download URLs):
#   hmda_nj_<YEAR>.csv           HMDA Data Browser CSV, NJ, all outcomes
#   filers_nj_<YEAR>.json        lender names (optional)
#   county_adjacency2023.txt     Census county adjacency file (optional)
# Committed with the code:
#   etl/lender_successor.csv     mergers we verified by hand (D17)
set -euo pipefail

cd "$(dirname "$0")/.."
# Homebrew installs psql outside the default PATH
for d in /opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@16/bin; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
DB="${DATABASE_URL:-postgresql:///mme}"
RAW="data/raw"
SAMPLE="${SAMPLE:-1}"
PSQL=(psql "$DB" -v ON_ERROR_STOP=1 -q -X)
STAGE_COLS=""

now() { date +%s; }
log() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }

T0=$(now)
log "Rebuilding schema from empty"
"${PSQL[@]}" -f db/schema.sql
"${PSQL[@]}" -f etl/seed_reference.sql

# ---------------------------------------------------------------------------
# County adjacency (Census, pipe-delimited: name|geoid|neighbor name|neighbor geoid)
# ---------------------------------------------------------------------------
if [[ -f "$RAW/county_adjacency2023.txt" ]]; then
  log "Loading county adjacency"
  "${PSQL[@]}" <<SQL
SET search_path TO mme;
CREATE TEMP TABLE adj_raw (county_name text, county_geoid text, neighbor_name text, neighbor_geoid text);
\copy adj_raw FROM '$RAW/county_adjacency2023.txt' WITH (FORMAT csv, DELIMITER '|', HEADER true)
INSERT INTO county_adjacency (county_fips, neighbor_fips)
SELECT DISTINCT county_geoid, neighbor_geoid
FROM adj_raw
WHERE county_geoid IN (SELECT county_fips FROM county)
  AND neighbor_geoid <> county_geoid;
SQL
else
  log "WARNING: $RAW/county_adjacency2023.txt missing, county_adjacency left empty"
fi

# ---------------------------------------------------------------------------
# One HMDA year
# ---------------------------------------------------------------------------
load_year() {
  local year="$1" file="$RAW/hmda_nj_$1.csv"
  local t_start; t_start=$(now)
  log "[$year] staging $file"

  # Staging table: every CSV column as text, named exactly as in the header.
  local cols
  cols=$(head -n 1 "$file" | tr -d '\r' | tr ',' '\n' | sed 's/^"//; s/"$//' \
         | awk '{printf "%s\"%s\" text", (NR>1?", ":""), $0}')
  STAGE_COLS=$(head -n 1 "$file" | tr -d '\r' | tr ',' '\n' | sed 's/^"//; s/"$//' \
         | awk '{printf "%s\"%s\"", (NR>1?", ":""), $0}')

  "${PSQL[@]}" <<SQL
SET search_path TO mme;
DROP TABLE IF EXISTS stage_raw;
CREATE UNLOGGED TABLE stage_raw (stage_id bigserial, $cols);
\copy stage_raw ($STAGE_COLS) FROM '$file' WITH (FORMAT csv, HEADER true, NULL '')
SQL

  "${PSQL[@]}" <<SQL
SET search_path TO mme;

-- Release row (admin import log)
INSERT INTO data_release (year, state_code, source_url, rows_read)
SELECT $year, 'NJ',
       'https://ffiec.cfpb.gov/v2/data-browser-api/view/csv?states=NJ&years=$year',
       count(*)
FROM stage_raw;

-- Optional sampling for 10k / 100k scale tests
SELECT setseed(0.42);
DELETE FROM stage_raw WHERE $SAMPLE < 1 AND random() >= $SAMPLE;

-- Cleaning: drop purchased loans (D16) and rows the app cannot place, and say why
CREATE TEMP TABLE dropped AS
SELECT stage_id,
       CASE WHEN action_taken = '6' THEN 'purchased loan (D16)'
            WHEN county_code IS NULL OR county_code NOT IN (SELECT county_fips FROM county) THEN 'county missing or not NJ'
            WHEN lei IS NULL OR length(lei) <> 20 THEN 'lei missing'
            WHEN num(loan_amount) IS NULL THEN 'loan_amount missing'
            WHEN num(loan_amount) > 2000000000 THEN 'loan_amount over 2 billion'
            WHEN num(occupancy_type) IS NULL OR num(lien_status) IS NULL THEN 'occupancy or lien missing'
       END AS reason
FROM stage_raw;
DELETE FROM dropped WHERE reason IS NULL;
SELECT '[$year] dropped' AS step, reason, count(*) FROM dropped GROUP BY reason ORDER BY 3 DESC;
UPDATE data_release
SET rows_dropped = (SELECT coalesce(jsonb_object_agg(reason, n), '{}'::jsonb)
                    FROM (SELECT reason, count(*) AS n FROM dropped GROUP BY reason) x)
WHERE release_id = (SELECT max(release_id) FROM data_release WHERE year = $year);
DELETE FROM stage_raw s USING dropped d WHERE s.stage_id = d.stage_id;

-- Lenders
INSERT INTO lender (lei)
SELECT DISTINCT lei FROM stage_raw ORDER BY lei
ON CONFLICT (lei) DO NOTHING;

-- Census tracts (attributes HMDA appends per row)
INSERT INTO census_tract (tract_fips, year, county_id, minority_pct, tract_to_msa_income_pct, owner_occupied_units)
SELECT DISTINCT ON (s.census_tract)
       s.census_tract::bigint, $year, c.county_id,
       num(s.tract_minority_population_percent),
       round(num(s.tract_to_msa_income_percentage)),
       num(s.tract_owner_occupied_units)
FROM stage_raw s
JOIN county c ON c.county_fips = s.county_code
WHERE s.census_tract ~ '^[0-9]{11}$'
ORDER BY s.census_tract
ON CONFLICT DO NOTHING;

-- Applications: ids are base + stage_id so denial reasons can be joined back
CREATE TEMP TABLE base AS SELECT coalesce(max(application_id), 0) AS b FROM application;

INSERT INTO application (
  application_id, lender_id, tract_fips,
  loan_amount, property_value, income_k, total_loan_costs, discount_points,
  year, county_id, action_taken, loan_type, loan_purpose, lien_status, occupancy,
  dti_bucket, loan_term, conforming, interest_rate, rate_spread)
SELECT
  (SELECT b FROM base) + s.stage_id,
  l.lender_id,
  CASE WHEN s.census_tract ~ '^[0-9]{11}$' THEN s.census_tract::bigint END,
  num(s.loan_amount),
  CASE WHEN num(s.property_value) <= 2000000000 THEN num(s.property_value) END,
  CASE WHEN abs(num(s.income)) <= 2000000000 THEN num(s.income) END,
  CASE WHEN abs(num(s.total_loan_costs)) <= 2000000000 THEN round(num(s.total_loan_costs)) END,
  CASE WHEN abs(num(s.discount_points)) <= 2000000000 THEN round(num(s.discount_points)) END,
  $year, c.county_id,
  num(s.action_taken), num(s.loan_type), num(s.loan_purpose), num(s.lien_status), num(s.occupancy_type),
  CASE s.debt_to_income_ratio
       WHEN '<20%' THEN 1 WHEN '20%-<30%' THEN 2 WHEN '30%-<36%' THEN 3
       WHEN '50%-60%' THEN 50 WHEN '>60%' THEN 61
       ELSE CASE WHEN num(s.debt_to_income_ratio) BETWEEN 36 AND 49 THEN num(s.debt_to_income_ratio) END
  END,
  CASE WHEN num(s.loan_term) <= 32767 THEN num(s.loan_term) END,
  CASE s.conforming_loan_limit WHEN 'C' THEN true WHEN 'NC' THEN false END,
  CASE WHEN num(s.interest_rate) BETWEEN 0 AND 99 THEN num(s.interest_rate) END,
  CASE WHEN abs(num(s.rate_spread)) < 99 THEN num(s.rate_spread) END
FROM stage_raw s
JOIN lender l ON l.lei = s.lei
JOIN county c ON c.county_fips = s.county_code;

-- Denial reasons: up to four per application, skip 10 (not applicable) and 1111 (exempt)
INSERT INTO application_denial_reason (application_id, reason)
SELECT DISTINCT (SELECT b FROM base) + s.stage_id, r.code::smallint
FROM stage_raw s
CROSS JOIN LATERAL (VALUES (num(s."denial_reason-1")), (num(s."denial_reason-2")),
                           (num(s."denial_reason-3")), (num(s."denial_reason-4"))) AS r(code)
WHERE r.code BETWEEN 1 AND 9;

UPDATE data_release
SET rows_loaded = (SELECT count(*) FROM stage_raw)
WHERE release_id = (SELECT max(release_id) FROM data_release WHERE year = $year);

DROP TABLE stage_raw;
SQL

  local secs=$(( $(now) - t_start ))
  "${PSQL[@]}" -c "UPDATE mme.data_release SET load_seconds = $secs WHERE year = $year;"
  log "[$year] done in ${secs}s"
}

shopt -s nullglob
files=("$RAW"/hmda_nj_*.csv)
if (( ${#files[@]} == 0 )); then
  echo "No $RAW/hmda_nj_<YEAR>.csv files found" >&2; exit 1
fi
for f in "${files[@]}"; do
  y=$(basename "$f" .csv); y=${y#hmda_nj_}
  load_year "$y"
done

# ---------------------------------------------------------------------------
# Lender names (Data Browser "filers" JSON: {"institutions":[{"lei","name",...}]})
# ---------------------------------------------------------------------------
for f in "$RAW"/filers_nj_*.json; do
  log "Lender names from $f"
  "${PSQL[@]}" <<SQL
SET search_path TO mme;
CREATE TEMP TABLE filers_raw (line_no bigserial, line text);
\copy filers_raw (line) FROM '$f' WITH (FORMAT csv, QUOTE E'\x01', DELIMITER E'\x02')
WITH doc AS (SELECT string_agg(line, E'\n' ORDER BY line_no)::jsonb AS j FROM filers_raw),
     inst AS (
       SELECT x FROM doc, jsonb_array_elements(
         CASE WHEN jsonb_typeof(j) = 'array' THEN j ELSE coalesce(j->'institutions', '[]'::jsonb) END) x)
UPDATE lender l SET name = inst.x->>'name'
FROM inst
WHERE l.lei = inst.x->>'lei' AND l.name IS NULL;
SQL
done

# ---------------------------------------------------------------------------
# Lender successors (D17): mergers, so "What changed?" doesn't report them as exits
# ---------------------------------------------------------------------------
log "Lender successors from etl/lender_successor.csv"
"${PSQL[@]}" <<SQL
SET search_path TO mme;
CREATE TEMP TABLE successor_raw (old_lei text, new_lei text, effective_date date, event text, source text);
\copy successor_raw FROM 'etl/lender_successor.csv' WITH (FORMAT csv, HEADER true)
INSERT INTO lender_successor (lender_id, successor_lender_id, effective_date, event, source)
SELECT o.lender_id, n.lender_id, r.effective_date, r.event, r.source
FROM successor_raw r
JOIN lender o ON o.lei = r.old_lei
JOIN lender n ON n.lei = r.new_lei;
DO \$\$
DECLARE skipped integer;
BEGIN
  SELECT count(*) INTO skipped
  FROM successor_raw r
  WHERE NOT EXISTS (SELECT 1 FROM lender WHERE lei = r.old_lei)
     OR NOT EXISTS (SELECT 1 FROM lender WHERE lei = r.new_lei);
  IF skipped > 0 THEN
    RAISE WARNING '% lender_successor row(s) skipped: LEI not in the loaded data', skipped;
  END IF;
END \$\$;
SQL

# ---------------------------------------------------------------------------
# Precomputed market summary (design alternative D9)
# ---------------------------------------------------------------------------
log "Building market_summary"
T_SUM=$(now)
"${PSQL[@]}" <<SQL
SET search_path TO mme;
INSERT INTO market_summary
SELECT year, county_id, lender_id, loan_purpose, loan_type,
       count(*),
       count(*) FILTER (WHERE action_taken = 1),
       count(*) FILTER (WHERE action_taken IN (3, 7)),
       count(*) FILTER (WHERE action_taken = 4),
       coalesce(sum(loan_amount) FILTER (WHERE action_taken = 1), 0)
FROM application
GROUP BY 1, 2, 3, 4, 5;
SELECT setval(pg_get_serial_sequence('application', 'application_id'), (SELECT max(application_id) FROM application));
ANALYZE;
SQL
log "market_summary built in $(( $(now) - T_SUM ))s"

# ---------------------------------------------------------------------------
# Report: rows, sizes, load times (paste into docs/data-plan.md)
# ---------------------------------------------------------------------------
log "Total load time: $(( $(now) - T0 ))s"
"${PSQL[@]}" -P pager=off <<'SQL'
SET search_path TO mme;
\echo '== Releases'
SELECT year, rows_read, rows_loaded, rows_dropped, load_seconds FROM data_release ORDER BY year;
\echo '== Tables'
SELECT c.relname AS table_name,
       c.reltuples::bigint AS approx_rows,
       pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
       pg_size_pretty(pg_indexes_size(c.oid)) AS index_size,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'mme' AND c.relkind = 'r'
ORDER BY pg_total_relation_size(c.oid) DESC;
\echo '== Database size'
SELECT pg_size_pretty(pg_database_size(current_database()));
SQL
