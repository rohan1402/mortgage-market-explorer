#!/usr/bin/env bash
# Prints the project brief: the "Project status" section of README.md and the latest changes.
# Runs by itself after `git pull` (.githooks/post-merge, switched on by ./setup.sh) and when
# Claude Code opens the repo (.claude/settings.json). Run it any time: scripts/status.sh
root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || root="$(dirname "$0")/.."
cd "$root" || exit 0

echo "==================== Mortgage Market Explorer: project status ===================="
# Same text as README, made easier to read in a terminal: tables become one line per row.
awk '
  function trim(s) { gsub(/^ +| +$/, "", s); return s }
  /<!-- status:start -->/ { on = 1; next }
  /<!-- status:end -->/   { on = 0 }
  !on { next }
  { gsub(/\*\*/, ""); gsub(/`/, "") }
  /^### / { sub(/^### /, ""); print $0 ":"; next }
  /^\|/ {
    split($0, f, "|")
    if (f[2] ~ /^ *(Due|-+) *$/) next
    printf "  - %s: %s (%s) [%s]\n", trim(f[2]), trim(f[3]), trim(f[5]), trim(f[6])
    next
  }
  { print }
' README.md
echo
echo "Latest changes on $(git branch --show-current 2>/dev/null || echo this branch):"
bash scripts/latest-activity.sh 2>/dev/null || true
behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
if [[ "$behind" -gt 0 ]]; then
  echo
  echo "You are $behind commit(s) behind GitHub. Run: git pull"
fi
echo "=================================================================================="
exit 0
