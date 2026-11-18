#!/usr/bin/env bash
# Looks at what upstream has that this fork's current branch lacks. Changes and pushes nothing.
# Usage: bash scripts/fork-sync.sh   (the steps after it: docs/fork-sync.md)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree is not clean; commit or set the changes aside first." >&2
  exit 1
fi
git remote get-url upstream > /dev/null || { echo "No 'upstream' remote (see docs/fork-sync.md)." >&2; exit 1; }

git fetch upstream
behind=$(git rev-list --count HEAD..upstream/main)
echo "$behind commit(s) in upstream/main that $(git rev-parse --abbrev-ref HEAD) does not have:"
git log --oneline HEAD..upstream/main | head -n 30
[ "$behind" -le 30 ] || echo "... and $((behind - 30)) more"

cat << 'NEXT'

Next:
  git rebase upstream/main
  (a migration number may collide: docs/fork-sync.md)
  run the verify skill, then: git push --force-with-lease origin luan/main
NEXT
