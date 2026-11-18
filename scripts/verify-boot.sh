#!/usr/bin/env bash
# Boots the real server on a throwaway embedded database (PGlite) and drives it over HTTP:
# health, first sign-up, a workspace, a message in its general channel, the message read back.
# Needs bun and curl; reads no .env and touches no real database. Usage: bun run verify:boot
# (docs/verification.md). The agent's own answer is proven by the fake-provider test in the verify skill.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/agentes-verify.XXXXXX")
port=${VERIFY_PORT:-3917}
base="http://localhost:$port"
jar="$work/cookies"
server_pid=""
cleanup() { [ -n "$server_pid" ] && kill "$server_pid" 2> /dev/null || true; rm -rf "$work"; }
trap cleanup EXIT

web="$PWD/apps/web/dist"
[ -d "$web" ] || web="$work"
env -i PATH="$PATH" HOME="${HOME:-$work}" PORT="$port" PUBLIC_URL="$base" WEB_DIR="$web" \
  DATABASE_URL="pglite://$work/db" AGENTES_SECRET="verify-only-secret-verify-only-secret-0123456789" \
  bun apps/server/src/main.ts > "$work/server.log" 2>&1 &
server_pid=$!

step() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; echo "--- server log tail" >&2; tail -n 20 "$work/server.log" >&2; exit 1; }

for _ in $(seq 1 120); do
  curl -fs "$base/api/health" > /dev/null 2>&1 && break
  kill -0 "$server_pid" 2> /dev/null || fail "server exited during boot"
  sleep 1
done
curl -fs "$base/api/health" > "$work/health.json" || fail "health"
step "health: $(cat "$work/health.json")"

call() { # method path [json]
  curl -s -b "$jar" -c "$jar" -X "$1" -H "origin: $base" -H "content-type: application/json" \
    ${3:+-d "$3"} -w '\n%{http_code}' "$base$2"
}
expect() { # label expected-status response
  local code=${3##*$'\n'}
  [ "$code" = "$2" ] || fail "$1 (status $code, wanted $2): ${3%$'\n'*}"
}

r=$(call POST /api/auth/sign-up/email '{"email":"verify@example.com","password":"correct horse battery","name":"verify"}')
expect "sign up" 200 "$r"; step "first account signed up (HTTP 200)"
r=$(call POST /api/app/organizations '{"name":"Verify","context":"A throwaway workspace."}')
expect "create workspace" 201 "$r"
body=${r%$'\n'*}
org=$(printf '%s' "$body" | bun -e 'console.log(JSON.parse(await Bun.stdin.text()).organization.id)')
chan=$(printf '%s' "$body" | bun -e 'console.log(JSON.parse(await Bun.stdin.text()).generalChannelId)')
step "workspace $org with its general channel $chan (HTTP 201)"
r=$(call POST "/api/app/organizations/$org/channels/$chan/messages" '{"body":"hello from verify"}')
expect "post message" 201 "$r"; step "message posted (HTTP 201)"
r=$(call GET "/api/app/organizations/$org/channels/$chan/messages")
expect "read messages" 200 "$r"
printf '%s' "${r%$'\n'*}" | grep -q "hello from verify" || fail "message not read back"
step "message read back from the channel"
echo "verify-boot: all steps passed on $(git rev-parse --short HEAD)"
