---
name: verify
description: agentes.chat verification routine. Use before declaring any change done, before opening or updating a pull request, and whenever a test fails or flakes. It boots the real server on a throwaway embedded database and drives it over HTTP, runs the fake-provider end-to-end test where an agent answers, runs the pre-PR gate (tests, typecheck, lint, boundaries, build), applies the three-rounds and flaky-test rules, and ends with a one-line stamp for the commit or PR message.
---

# Verify

A passing unit test says little; a real boot driven end to end says a lot. Run the cheap layers first, the real boot before any PR, and keep the evidence.

## 1. Real boot, driven over HTTP

`bun run verify:boot` (`scripts/verify-boot.sh`, needs bun and curl, no `.env`, no Docker). It starts `apps/server/src/main.ts` with `DATABASE_URL=pglite://<temp folder>` (the database built into the server, deleted on exit; never a real or production URL), then checks and prints PASS per step: `/api/health`, first sign-up, creating a workspace, posting a message in its general channel, reading it back. On failure it prints the server log tail and exits 1.

- Windows: bun's install of the phone app's dependencies fails there, so boot in a Linux checkout (WSL or CI). In WSL: `bun install --frozen-lockfile --backend=copyfile`, then `bun run verify:boot`. Use one WSL call per need; repeated root-user calls have coincided with Docker restarts.
- Evidence to keep: the PASS lines and the exit code.

## 2. An agent answers (fake provider)

The real server has no fake model, so this layer is the in-process end-to-end test, on PGlite and the fake provider from `@agenteschat/providers/testing`:

`bun test apps/server/test/api.test.ts -t "workers run the agent"`

It signs up, makes a workspace, channel, credential and agent, posts `@dev status?`, drains the workers and reads the agent's reply and the usage record. Keep the exit code and the `pass` count.

## 3. Gate before any PR

Same checks as CI (`scripts/ci-local.sh`; `bun run ci:local` runs them all where shellcheck and gitleaks exist). At minimum, per touched area:

1. `bun test <the files you touched>`, then `bun test` for the packages around them.
2. `bunx tsc -p tsconfig.json --checkers 1` in each touched package (or `bun run typecheck`).
3. `bunx biome check <changed files>`. Never `--write` on a directory: CRLF checkouts rewrite thousands of files.
4. `bun run check:boundaries`.
5. `bun run build` when web or server code changed.
6. Layers 1 and 2.

## 4. Rules

- Three rounds. If the same failure survives 3 rounds of fixes, stop and ask the human with what you tried and the output; do not keep guessing.
- Flaky tests are never skipped, retried or slept on. Find the root cause (shared state, ordering, a real clock, a leaked timer), or delete the test and write why in the commit message.
- Never edit the checks that judge your own change (`.github/`, `scripts/ci-local.sh`, `.claude/`, `REVIEW.md`, `CLAUDE.md`) in the same change as the work. A change to them is its own PR, reviewed by their owner (`.github/CODEOWNERS`).
- The tree must stay as it was: no stray generated files, no mass reformat, LF endings in new files.

## 5. Stamp

End the commit or PR message with one line of what actually ran, for example:

`Verified: verify:boot PASS (6 steps), api.test agent reply PASS, tsc engine+server PASS, biome 9 files PASS, check:boundaries PASS, build not run (no web change).`

Say what was not run and why; never imply a check that did not run.
