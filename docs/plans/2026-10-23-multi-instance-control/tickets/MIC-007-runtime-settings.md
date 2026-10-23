# MIC-007 — Runtime settings: `aiur set <key> <value>` for allowlisted keys, validated by the running build

**Kind:** executable
**Provenance:** planned in plan v1
**Extends:** the existing `aiur set max-agents` (persisted since #5402); remote use comes free through MIC-002
**Complexity:** 3 — new config layer with validation and reload integration
**Risk:** medium (a bad layer can stop config loading)
**Lane:** NUC
**Phase hint:** 1
**Depends on:** none
**Requirements:** R9, R11, R12, R13
**Researched at:** ab0c21424

Plan context: [plan](../../2026-10-23-001-feat-multi-instance-control-plan.md) (KTD8, KTD9, F2, U7, AE4, AE5) · [pack index](../README.md)

## Outcome

An operator changes caps, routing, or backend priority on any instance with `aiur [--instance <name>] set <key> <value>`; the instance's own build accepts or refuses the value before it is stored; the change is live within a second and survives restarts.

## Context and evidence

- `aiur set` accepts only `max-agents` (`packaging/npm/aiur-cli/libexec/engine/commands.sh:309-329`).
- Unknown config keys are dropped silently by `cast` (`src/lib/aiur/config/schema.ex:202-214`), so a misspelled or too-new key is a silent no-op today.
- A hot reload that fails validation keeps the last good config (`src/lib/aiur/workflow_store/reload.ex:85-100`, #3980), but boot has no fallback (`src/lib/aiur/workflow_store.ex:218-229`). The 2026-10-10 crashes were invalid values on a build without #3980, not unknown keys.
- `TestRunOverrides.apply` is already a post-parse layer in `Aiur.Config.settings_from/1` (`src/lib/aiur/config.ex:153-156`).
- Per-instance state paths: `src/lib/aiur/config/paths.ex:42-60`.

## Scope

- `Aiur.Config.Overrides`: file `~/.aiur/instances/$AIUR_INSTANCE_KEY/config-overrides.json` (under `AIUR_STATE_DIR` when set, #5940). The path comes from the environment only, never from config: `Aiur.Config.Paths.decision_state_dir` resolves through `Config.settings!()` (`src/lib/aiur/config/paths.ex:42-60`, `src/lib/aiur/tracker.ex:282-283`) and would loop. Shape: `{"version":1,"revision":7,"entries":{"agent.max_concurrent_builds":{"value":2,"revision":7,"set_by":"token:pc-executor","set_at":"2026-10-23T18:04:11Z","build":"0.x.y+abc1234"}}}`.
- Merge entries into the workflow config map inside `Reload.load_state` (KTD8), so the reload validation (`src/lib/aiur/workflow_store/reload_rejection.ex:29-35`), the last-good guard, and boot all validate YAML plus overrides together. Add the file to the reload stamp in `src/lib/aiur/workflow_store/reload.ex:167-181`.
- Per key, state whether it applies live or at restart; `set` prints which. Verify each key's consumer re-reads `settings()` (for example the build gate for `agent.max_concurrent_builds`) and mark the others `restart`.
- `set(key, json_value, actor)`: refuse keys outside the allowlist (KTD9) with `unknown setting on this build (<version>)`; build the candidate (YAML + entries + new value) and run `Schema.parse`; refuse with the changeset message on error; otherwise write atomically.
- `unset(key, actor)`, `list()`.
- Boot (`WorkflowStore.init`, `src/lib/aiur/workflow_store.ex:218-229`): if YAML + overrides fails to parse but YAML alone parses, move the overrides file to `config-overrides.rejected-<ts>.json`, boot on YAML, and emit `config.override_rejected` (AE5).
- Engine: `aiur set <dotted.key> <json>`, `aiur set --list [--json]`, `aiur set --unset <key>`; `max-agents` keeps its current path. Actor: the token name for remote calls (MIC-002 passes it as an argument through `ControlCall.run/3`), `local:$USER` otherwise.

## Non-goals

- Writing `.aiur/config`. Ownership rules (MIC-008 adds `instance.owns` to the allowlist). Compare-and-set.

## Existing owner and reuse target

`Aiur.Config` and `Aiur.Config.Schema`; `ControlLifecycleStore.update_checked` for atomic-write style (`src/lib/aiur/orchestrator/control_lifecycle_store.ex:17-58`); the alert that `ReloadRejection` raises for a rejected reload (`src/lib/aiur/workflow_store/reload_rejection.ex`) as the model for `config.override_rejected`.

## Contract and invariants

Precedence: session `max-agents` > overrides > YAML > defaults. An override that the running build rejects is never stored. The YAML file is never modified.

## Refreshable implementation notes

- New: `src/lib/aiur/config/overrides.ex`, `src/lib/aiur/control_cli/settings.ex` (CLI entry, add to `Aiur.AgentControlCLI` and to MIC-001's allowlist as `:write` / `:read` for `--list` — if MIC-001 has not merged, add the allowlist entries in whichever lands second).
- Edit: `src/lib/aiur/workflow_store/reload.ex` (merge and stamp), `src/lib/aiur/workflow_store.ex` (boot fallback), `packaging/npm/aiur-cli/libexec/engine/commands.sh`.
- Tests: `src/test/aiur/config/overrides_test.exs`; launcher test for argument passing.

## Acceptance and verification

### Acceptance criteria

1. `aiur set agent.max_concurrent_builds 2` stores the entry, and within one reload poll the build gate admits at most 2 concurrent builds (assert the behaviour, not only `settings!()`).
2. `aiur set agent.max_concurrent_buildz 2` exits nonzero with `unknown setting on this build` and stores nothing (AE4).
3. `aiur set agent.routing '{"bad":true}'` exits nonzero with the schema error and stores nothing.
4. `aiur set --list` shows key, value, source `override`, revision, actor; `--json` emits the same fields.
5. `aiur set --unset agent.max_concurrent_builds` restores the YAML value.
6. Overrides survive a restart.
7. Boot with an override the build rejects starts on YAML, renames the file, and raises `config.override_rejected` (AE5).

### Test that fails without the change

Criterion 2 at the module level: `Overrides.set("agent.max_concurrent_buildz", 2, "local:test")` returns `{:error, {:unknown_setting, _}}`; today the key would be accepted by YAML parsing and ignored. Criterion 7: boot test with a rejected file expects `WorkflowStore` to start; today an invalid layer cannot exist, so write the test against the new boot fallback and confirm it fails with the fallback hunk reverted.

### Human/manual evidence

`aiur --instance nuc set agent.max_concurrent_builds 1` from the PC (MIC-010).

## Docs to update

- `website/docs-app/reference/cli.md`: change the `set` row to `set <key> <value> | --list | --unset <key>` (no new rows).
- `website/docs-app/reference/configuration.md`: a short "Runtime overrides" paragraph naming the allowlisted keys and precedence (keys keep their existing single entries).

## Files it touches

Listed above.

## Dependencies and conflicts

- depends_on: none.
- serializes_with: none (cli.md edits are row edits; see the pack's hot-file exception).

## First slice Kevin can try

Locally: `aiur set agent.max_concurrent_builds 2`, `aiur set --list`, `aiur set --unset agent.max_concurrent_builds`.
