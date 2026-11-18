# Verification

How a change is checked before it merges, and the settings that keep the checks honest.

- The agent's routine is `.claude/skills/verify/SKILL.md`: the pre-PR gate, a real boot driven over HTTP,
  the three-rounds rule and the flaky-test rule. `bun run verify:boot` is its boot step.
- What a reviewer looks for is `REVIEW.md`. Both it and the CI workflow are read from the base branch.
- `.github/CODEOWNERS` names the owner for the files that judge a change (`.github/`, `scripts/ci-local.sh`,
  `.claude/`, `REVIEW.md`, `CLAUDE.md`), so a change cannot quietly edit its own checks.
- `.claude/settings.json` has a Stop hook that runs a fast check and, for now, only logs what it would block.

## Settings only the repository owner can turn on

On GitHub, Settings, Branches, add a rule for `luan/main`:

1. Require a pull request before merging.
2. Require review from Code Owners (this is what makes CODEOWNERS bind).
3. Require status checks to pass before merging: the jobs of `.github/workflows/ci.yml`.
4. Do not allow bypassing the rule, and (optionally) require branches to be up to date.

Without 2 and 3 the files above are only a convention.
