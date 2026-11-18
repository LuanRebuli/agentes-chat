#!/usr/bin/env bash
# Stop hook: a fast check when the agent finishes a turn (Biome on the changed files, then boundaries).
# OBSERVE mode (the default): what would be blocked is written to .claude/verify-hook.log and the agent is
# never stopped. To ENFORCE, set "AGENTES_HOOK_MODE": "enforce" in the "env" of .claude/settings.json: a
# failure then exits 2 with the findings on stderr, which makes the agent keep working. The loop guard
# (stop_hook_active) lets it stop after one forced round, and the 3-rounds rule of the verify skill still applies.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
mode=${AGENTES_HOOK_MODE:-observe}
log=.claude/verify-hook.log

input=$(cat)
case "$input" in *'"stop_hook_active":true'* | *'"stop_hook_active": true'*) exit 0 ;; esac

files=$( { git diff --name-only --diff-filter=d HEAD; git ls-files --others --exclude-standard; } 2> /dev/null |
  grep -E '\.(ts|tsx|js|jsx|json|css)$' | sort -u)
[ -n "$files" ] || exit 0

out=""
# shellcheck disable=SC2086
out+=$(bunx biome check $files 2>&1) || out="lint: $out"
b=$(bun run check:boundaries 2>&1) || out="$out
boundaries: $b"

case "$out" in
  *"lint:"* | *"boundaries:"*)
    {
      echo "== $(date -u +%FT%TZ) mode=$mode would block"
      echo "$out" | head -n 40
    } >> "$log"
    if [ "$mode" = enforce ]; then
      echo "$out" | head -n 40 >&2
      exit 2
    fi
    ;;
esac
exit 0
