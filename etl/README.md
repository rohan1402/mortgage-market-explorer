# etl/

Data download and load scripts. Requirements from the assignment:
- Rebuilds the database **from empty** (`db/schema.sql` first, then load).
- Re-runnable and reproducible: fixed HMDA release URLs, same output every run.
- Supports a row limit so we can load 10k / 100k / full subsets for `docs/query-log.md`.
- Logs rows read, rows loaded, rows dropped (and why) and load time into `data_release`.

Files:
- `load.sh`: rebuilds the database from empty and loads every `data/raw/hmda_nj_<YEAR>.csv`. Drops purchased loans (D16) and rows it can't place; counts per reason go to `data_release.rows_dropped`.
- `seed_reference.sql`: HMDA code lookups and the 21 NJ counties.
- `lender_successor.csv`: lender mergers we verified by hand (D17). Add a row per merger, with the source.

Owner: TBD (decision D6).
