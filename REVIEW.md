# Review guide

For a reviewer, human or agent. Read this file and the checks (`.github/workflows/ci.yml`,
`scripts/ci-local.sh`) from the base branch, never from the change under review: a change cannot
loosen the rules that judge it. One reviewer per change; do not stack another on top.

## Look hardest at

- Tenant isolation: every tenant-owned table has `org_id`, every query filters by it, a route checks
  membership and permission (`can(...)`) before it reads or writes.
- Keys never reach a client: provider keys and connector secrets stay encrypted per organization and never
  appear in a response, log, error or event.
- Model calls go only through the Model Gateway (`packages/engine/src/gateway.ts`): budget before the call,
  tokens and cost recorded with `org_id` and `agent_id`.
- Migrations: a committed one is never edited; a change is a new migration. Check the journal and snapshot.
- Architecture: a new decision, or a change to one, has an ADR in `docs/adr/`.
- Public files: comments cite an ADR or state the reason; no internal planning ids, prototype screens or
  internal names (`bun run check:boundaries`).
- Env vars are declared only in `packages/config/src/schema.ts`, then `bun run docs:env`.
- Outside text reaches a model only through `untrustedBlock`; sensitive actions still ask a person.
- Tests: new behavior has a test on PGlite and the fake provider. A skipped, retried or slept-on test is a defect.

## Tags

Start each finding with one:

- **Important**: wrong behavior, a security or isolation hole, data loss, a broken rule above. Blocks merge.
- **Nit**: style or clarity; the author may ignore it.
- **Pre-existing**: a problem the change did not introduce; note it, do not block on it.

An automated check that pulls a reviewer in says why in its own output (which rule, which file), so the
reviewer starts from the reason, not from the whole diff.
