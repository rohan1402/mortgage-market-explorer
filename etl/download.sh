#!/usr/bin/env bash
# Downloads the raw files etl/load.sh needs into data/raw/ (git-ignored, about 660 MB for 4 years).
# Skips files that are already there, so it is safe to re-run after a failed download.
#
# Usage:
#   etl/download.sh                  # NJ 2021–2024
#   YEARS=2023 etl/download.sh       # one year only (about 110 MB), for a quick start
set -euo pipefail

cd "$(dirname "$0")/.."
RAW="data/raw"
YEARS="${YEARS:-2021 2022 2023 2024}"
HMDA="https://ffiec.cfpb.gov/v2/data-browser-api/view"   # HMDA Data Browser API (FFIEC/CFPB)
ADJ="https://www2.census.gov/geo/docs/reference/county_adjacency/county_adjacency2023.txt"
mkdir -p "$RAW"

command -v curl >/dev/null || { echo "curl is missing: install it, then re-run" >&2; exit 1; }

# fetch <url> <file> <description> [<text the file must start with>]
fetch() {
  local url="$1" out="$2" what="$3" starts="${4:-}"
  if [[ -s "$out" ]]; then echo "  have $out"; return; fi
  echo "  downloading $what"
  if ! curl -fL --retry 3 --retry-delay 5 --progress-bar -o "$out.part" "$url"; then
    rm -f "$out.part"
    echo "Download failed: $url" >&2
    echo "Re-run the same command; finished files are kept." >&2
    exit 1
  fi
  if [[ -n "$starts" && "$(head -c ${#starts} "$out.part")" != "$starts" ]]; then
    echo "Unexpected content from $url (saved as $out.part to look at)" >&2
    exit 1
  fi
  mv "$out.part" "$out"
}

for y in $YEARS; do
  fetch "$HMDA/csv?states=NJ&years=$y" "$RAW/hmda_nj_$y.csv" \
        "HMDA NJ $y (110-270 MB; the server builds the file first, so it can sit at 0% for a while)" activity_year
  fetch "$HMDA/filers?states=NJ&years=$y" "$RAW/filers_nj_$y.json" "lender names $y" '{'
done
fetch "$ADJ" "$RAW/county_adjacency2023.txt" "Census county adjacency" "County Name"

echo "Raw data ready in $RAW/"
