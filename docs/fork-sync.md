# Keeping this fork current with upstream

This fork keeps its own work on `luan/main`, on top of the upstream project's `main`. Upstream is
read only for us: nothing is ever pushed to it.

```
upstream  https://github.com/agentes-chat/agentes-chat   (fetch only)
origin    https://github.com/LuanRebuli/agentes-chat     (this fork)
```

## Bringing upstream in

1. `bash scripts/fork-sync.sh` checks the tree is clean, fetches `upstream` and says how many
   commits are waiting. It changes and pushes nothing.
2. `git rebase upstream/main` on `luan/main`. Fix each conflict, `git rebase --continue`.
3. Run the verify skill (`.claude/skills/verify/SKILL.md`): the whole gate, then `bun run verify:boot`.
4. Push with `git push --force-with-lease origin luan/main` once the gate is green.

## Where conflicts come from

- Migrations. Numbers are taken in order, so upstream may have used the number our
  `0286_auto_policy` holds. On a rebase, rename the file to the next free number and change the
  matching `idx` and `tag` in `packages/db/migrations/meta/_journal.json` and the snapshot file
  beside it. Committed migrations are immutable only once released; ours is not yet upstream.
  Then run `bun run db:generate ci-drift-check` and expect no new files.
- Our content lives in few files (the router's Automatico policy in `packages/engine/src`, its
  settings screen, ADR 0189), so a conflict is usually in one of them. Keep upstream's change and
  re-apply ours on top; never the other way round.
- `bun.lock` and `.env.example` regenerate (`bun install`, `bun run docs:env`); do not merge them by hand.

The two GitHub settings the owner turns on are in `docs/verification.md`.
