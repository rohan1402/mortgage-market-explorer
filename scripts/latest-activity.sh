#!/usr/bin/env bash
# Lists the latest changes on the current branch, newest first, one line each.
#   scripts/latest-activity.sh           print them
#   scripts/latest-activity.sh --write   also refresh the "Latest activity" block in README.md
# .github/workflows/readme-activity.yml runs --write on every push to main.
set -euo pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
N="${N:-5}"
BOT="github-actions[bot]"

lines() {
  local c=0 h subj title
  for h in $(git log --first-parent -n 40 --format=%H); do
    [[ "$(git log -1 --format=%an "$h")" == "$BOT" ]] && continue
    subj=$(git log -1 --format=%s "$h")
    # A GitHub merge commit says "Merge pull request #N from ..."; its body holds the PR title.
    if [[ $subj =~ ^Merge\ pull\ request\ (#[0-9]+) ]]; then
      title=$(git log -1 --format=%b "$h" | sed -n '/./{p;q;}')
      subj="Merged PR ${BASH_REMATCH[1]}${title:+: $title}"
    fi
    printf -- '- %s · %s · %s\n' "$(git log -1 --date=short --format=%ad "$h")" \
      "$(git log -1 --format=%an "$h")" "$subj"
    c=$((c + 1)); [[ $c -lt $N ]] || break
  done
}

if [[ "${1:-}" != "--write" ]]; then
  lines
  exit 0
fi

BODY="$(lines)" awk '
  /<!-- activity:start -->/ { print; print ""; print ENVIRON["BODY"]; print ""; skip = 1; next }
  /<!-- activity:end -->/   { skip = 0 }
  !skip
' README.md > README.md.tmp
mv README.md.tmp README.md
