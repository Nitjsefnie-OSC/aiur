# MIC-004 — `aiur --instance all <read-command>`: fan-out reads across every registered instance

**Kind:** executable
**Provenance:** planned in plan v1
**Extends:** new; complements #5950 (that roster is heartbeat discovery from the lease store; this is live per-instance output through each instance's own CLI path)
**Complexity:** 2 — client loop over an existing transport
**Risk:** low
**Lane:** NUC
**Phase hint:** 2
**Depends on:** MIC-003
**Requirements:** R4
**Researched at:** ab0c21424

Plan context: [plan](../../2026-10-23-001-feat-multi-instance-control-plan.md) (U4, AE1, AE2) · [pack index](../README.md)

## Outcome

`aiur --instance all agents` shows every instance's agents in one run, each block headed by its instance name, and an unreachable instance is shown as unreachable, never omitted.

## Context and evidence

- MIC-003 adds `run_remote_rpc_with_timeout` for one instance.
- The read/write classification is the client mirror of MIC-001's allowlist; the client decides before any network call so `all` never sends a write.
- AGENTS.md "Computed ages and collapsed causes": a failed source keeps its cause, it does not collapse to an empty result.

## Scope

- `--instance all` runs the command once per registry entry, in parallel, each bounded by the normal timeout.
- Text mode: `== <name> (<url host>) ==` header then that instance's output; `== <name> == unreachable: <reason>` for transport errors.
- `--json`: one JSON line per instance: `{"instance":"nuc","ok":true,"exit_code":0,"output":"<raw>"}` or `{"instance":"nuc","ok":false,"error":"<code>","detail":"..."}` — raw output is not re-parsed.
- Exit code: 0 when every instance exits 0; otherwise the highest nonzero exit.
- Write-scope commands with `all` exit 64 before any request ("--instance all is for read commands").
- A client-side read-command list in `remote.sh`; a test asserts it equals the `:read` entries of MIC-001's allowlist by name (the engine census fixture).

## Non-goals

- `executor-wait` with `all` (MIC-006). Aggregated tables that merge rows across instances.

## Existing owner and reuse target

`engine/remote.sh` from MIC-003; Bun fixture server from MIC-003's test.

## Contract and invariants

Every registered instance appears exactly once in the output, live or not.

## Refreshable implementation notes

- Edit: `packaging/npm/aiur-cli/libexec/engine/remote.sh`.
- Test: extend `packaging/npm/aiur-cli/test/launcher-remote.test.mjs` with two fake servers, one down.

## Acceptance and verification

### Acceptance criteria

1. Two live fakes: both outputs print with headers; exit 0.
2. One fake down: the live block prints, the down instance prints `unreachable` with the transport reason; exit nonzero (AE1).
3. `aiur --instance all pause` exits 64 and no fake receives a request (AE2).
4. `--json` emits one line per instance with `instance` set.

### Test that fails without the change

Two-fake test of criterion 2 expects a `nuc ... unreachable` line; before the change `all` is looked up as an instance name and exits 64 "unknown instance all".

### Human/manual evidence

`aiur --instance all agents` with PC and NUC registered (MIC-010).

## Docs to update

`website/docs-app/reference/cli.md`: extend the `--instance` row with `all` (reads only); no new row.

## Files it touches

`engine/remote.sh`, `test/launcher-remote.test.mjs`, `reference/cli.md`.

## Dependencies and conflicts

- depends_on: MIC-003 (extends its file).
- serializes_with: none in phase 2.

## First slice Kevin can try

`aiur --instance all agents` and `aiur --instance all alerts`.
