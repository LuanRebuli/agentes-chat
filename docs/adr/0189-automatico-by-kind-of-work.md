# 0189. Automático by the kind of work: a workspace policy gives the tier and effort

- Status: Accepted
- Date: 2026-11-16
- Extends: ADR 0087 (Automático and the tiers of each provider's line), ADR 0059 (coding plans as key accounts)
- Code: `packages/engine/src/auto-model.ts` (`AUTO_ACTIVITIES`, `AutoPolicy`, `SUGGESTED_AUTO_POLICY`, `autoPolicyOf`,
  `orgAutoPolicy`, `chooseAutoModel`'s `policy`, `fallbackChoice`, `antigravityModelForTier`, `brainModelForTier`),
  `packages/engine/src/executor.ts` (`askAuto`), `packages/engine/src/management.ts` (`autoPolicy` in the settings),
  `packages/db/src/schema/agents.ts` (`organization_settings.auto_policy`, migration `0286_auto_policy`),
  `apps/server/src/routes/app/management.ts`, `packages/client/src/api/types.ts`

## Context

An agent whose model or effort is Automático gets a judge (`chooseAutoModel`) that reads the run and answers two
questions on their own: how capable a model (tier) and how hard it should think (effort). The two answers drift
apart in ways an owner can't predict: the same kind of work lands on a different pair from one run to the next.
Owners on a plan with a limited quota want a rigid pairing they can reason about: deciding and reviewing get the
large model thinking briefly, conversation the everyday one, carrying out work already decided a small model that
thinks hard and checks itself.

Antigravity (Google's CLI brain) had no mapping from a tier at all: its model slug already carries the thinking
level (`gemini-4-argon-high`), so Automático left it on its default.

## Decision

1. **A workspace policy**, `organization_settings.auto_policy` (nullable jsonb), gives each kind of work a tier and an
   effort: `{ think, talk, execute }`, each `{ tier, effort }`.
   - `think`: planning, deciding, reviewing, finding a subtle cause.
   - `talk`: conversation and coordination.
   - `execute`: carrying out work already decided.
   Null (the default) is what it was: the judge picks tier and effort independently. A policy is read only whole
   (`autoPolicyOf`): all three kinds, each with a tier and an effort, nothing else; settings refuse anything else
   with a validation error, and null clears it.
2. **Under a policy the judge classifies only.** `chooseAutoModel` asks one `activity` question with the three
   kinds and maps the answer through the policy. The run's record (`autoModel`, the `context` step) says which kind
   it read (`activity`) and the reason names it. A timeout, a failure or an answer off the list takes the policy's
   `talk` line instead of medium/medium.
3. **The suggested policy** (`SUGGESTED_AUTO_POLICY`, offered by the apps, never applied by the server on its own):
   think = large and low, talk = medium and medium, execute = small and high.
4. **Antigravity maps tiers too.** `antigravityModelForTier(tier, effort)` takes the listed slug of a catalog model of
   that tier (else the nearest larger tier, then the nearest smaller) at the effort, else the nearest level the model
   has (medium before the other). `brainModelForTier` takes the effort for it, and `autoApplied` passes the choice's.
5. The setting is part of `GET`/`PATCH …/settings` (`autoPolicy`), read in `getOrgSettings` and cached per workspace
   (`orgAutoPolicy`), like the tiers' own models.

## Consequences

- Cost and speed are predictable per kind of work, and the owner decides the trade instead of the judge.
- The old guard, "never the small tier when acting with tools", does not hold under a policy: `execute` may put the
  small tier on a run that uses tools. That is the owner's explicit choice in the policy, made knowing what it gives
  up; without a policy the guard stands.
- Classification is one question instead of two, so the judge's call is a little cheaper.
- Antigravity has no `argon-low` slug: large and low runs on `gemini-4-argon-medium`, the nearest level. Its small
  and medium tiers share the Flash model, which has all three levels.
- A run resumed after an approval keeps its choice, as before; a change to the policy applies to the next run.
- Migration `0286_auto_policy` only adds a nullable column.

## Alternatives

- **Fixed tier and effort per agent**: no judge at all, but an agent that talks and then carries out work needs both,
  and "Automático" exists so nobody picks per message.
- **Letting the judge keep both questions and clamp them**: still unpredictable, and the clamp hides what the policy
  is.
- **A policy per agent**: more to set up. The workspace policy is the first step; an agent's own can be added on the
  same shape.
