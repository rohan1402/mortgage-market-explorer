# etl/

Data download and load scripts. Requirements from the assignment:
- Rebuilds the database **from empty** (`db/schema.sql` first, then load).
- Re-runnable and reproducible: fixed HMDA release URLs, same output every run.
- Supports a row limit so we can load 10k / 100k / full subsets for `docs/query-log.md`.
- Logs rows read, rows loaded, rows dropped (and why) and load time into `data_release`.

Run `./setup.sh` from the repo root to do everything at once. By hand: `etl/download.sh`, then `etl/load.sh`.

Files:
- `download.sh`: downloads the raw files into `data/raw/` (git-ignored), skipping ones already there. `YEARS=2023` for one year.
  - HMDA records: `https://ffiec.cfpb.gov/v2/data-browser-api/view/csv?states=NJ&years=<YEAR>` → `hmda_nj_<YEAR>.csv`
  - Lender names: `https://ffiec.cfpb.gov/v2/data-browser-api/view/filers?states=NJ&years=<YEAR>` → `filers_nj_<YEAR>.json`
  - County neighbors: `https://www2.census.gov/geo/docs/reference/county_adjacency/county_adjacency2023.txt`
- `load.sh`: rebuilds the database from empty and loads every `data/raw/hmda_nj_<YEAR>.csv`. Drops purchased loans (D16) and rows it can't place; counts per reason go to `data_release.rows_dropped`.
- `seed_reference.sql`: HMDA code lookups and the 21 NJ counties.
- `lender_successor.csv`: lender mergers we verified by hand (D17). Add a row per merger, with the source.

Owner: TBD (decision D6).
