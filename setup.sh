#!/usr/bin/env bash
# One-command setup: PostgreSQL, the local `mme` database, the raw HMDA data, the full load,
# and the git hook that shows the project status after every pull.
# Safe to re-run: it skips whatever is already done.
#
#   ./setup.sh                 NJ 2021–2024 (about 660 MB download, then about a minute to load)
#   YEARS=2023 ./setup.sh      one year only, for a quick start
#   RELOAD=1 ./setup.sh        rebuild the database even if it is already loaded
#   DATABASE_URL=postgresql://... ./setup.sh   use an existing (e.g. hosted) database instead
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\n==> %s\n' "$*"; }
stop() { printf '\nSetup stopped: %s\n' "$*" >&2; exit 1; }
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
as_postgres() { if [[ $EUID -eq 0 ]]; then runuser -u postgres -- "$@"; else sudo -u postgres "$@"; fi; }

# psql from Homebrew or Postgres.app is not on the default PATH
for d in /opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@16/bin \
         /Applications/Postgres.app/Contents/Versions/latest/bin; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
export PATH

step "1/5 PostgreSQL"
if ! command -v psql >/dev/null; then
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null || stop "install Homebrew from https://brew.sh, then run ./setup.sh again"
      brew install postgresql@16
      PATH="$(brew --prefix)/opt/postgresql@16/bin:$PATH" ;;
    Linux)
      command -v apt-get >/dev/null || stop "install PostgreSQL 16 with your package manager, then run ./setup.sh again"
      echo "Installing PostgreSQL (asks for your password)"
      $SUDO apt-get update -qq && $SUDO apt-get install -y -qq postgresql ;;
    *)
      stop "on Windows, run this inside WSL (Ubuntu); see README.md" ;;
  esac
fi
echo "psql: $(psql --version)"

if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "Using DATABASE_URL; skipping the local server and database steps"
else
  if ! pg_isready -q; then
    echo "Starting the local Postgres server"
    case "$(uname -s)" in
      Darwin) command -v brew >/dev/null || stop "start Postgres (e.g. open Postgres.app), then run ./setup.sh again"
              brew services start postgresql@16 ;;
      *)      $SUDO service postgresql start ;;
    esac
    for _ in 1 2 3 4 5 6 7 8 9 10; do pg_isready -q && break; sleep 1; done
    pg_isready -q || stop "Postgres is installed but did not start"
  fi
  # Linux packages only create the "postgres" role; add one for you (macOS Homebrew already has it)
  if ! psql -d postgres -Atqc 'SELECT 1' >/dev/null 2>&1; then
    echo "Creating a Postgres role for $(whoami)"
    as_postgres createuser -s "$(whoami)"
  fi
fi

step "2/5 Database"
if [[ -z "${DATABASE_URL:-}" ]]; then
  if [[ "$(psql -d postgres -Atqc "SELECT 1 FROM pg_database WHERE datname = 'mme'")" == 1 ]]; then
    echo "Database mme already exists"
  else
    createdb mme && echo "Created database mme"
  fi
fi
DB="${DATABASE_URL:-postgresql:///mme}"
psql "$DB" -Atqc 'SELECT 1' >/dev/null || stop "cannot connect to $DB"

step "3/5 Raw data (data/raw/, not committed)"
etl/download.sh

step "4/5 Load"
rows=$(psql "$DB" -Atqc 'SELECT count(*) FROM mme.application' 2>/dev/null || echo 0)
if [[ "$rows" -gt 0 && -z "${RELOAD:-}" ]]; then
  echo "Already loaded ($rows applications). To rebuild: RELOAD=1 ./setup.sh"
else
  DATABASE_URL="$DB" etl/load.sh
fi

step "5/5 Git hook"
if git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath .githooks
  echo "You'll see the project status after every git pull"
fi

rows=$(psql "$DB" -Atqc 'SELECT count(*) FROM mme.application')
printf '\nDone: %s applications loaded. Open the database with:  psql %s\n\n' "$rows" "$DB"
scripts/status.sh
