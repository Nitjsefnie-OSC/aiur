# MIC-002 — `POST /api/v1/control`: run allowlisted control calls for scoped bearer tokens, with an audit log

**Kind:** executable
**Provenance:** planned in plan v1
**Extends:** #5945 (consumes its token plug, token store and `read`/`write` scopes; adds the control route and the audit log that #5945 does not cover)
**Complexity:** 3 — new network write path with auth and audit
**Risk:** high
**Lane:** PC
**Phase hint:** 2
**Depends on:** MIC-001, #5945
**Requirements:** R6, R7, R8, R9
**Researched at:** ab0c21424

Plan context: [plan](../../2026-10-23-001-feat-multi-instance-control-plan.md) (KTD1, KTD5, KTD6, U2) · [pack index](../README.md)

## Outcome

A machine client with a bearer token can run any remote-capable control command on an instance over HTTPS and gets back the same text and exit code a local `aiur` run prints; every write and every refusal is recorded.

## Context and evidence

- No control verb except per-ticket pause/resume/message has an HTTP route today (`src/lib/aiur_web/routes/api.ex:9-36`); global pause, caps, park, take/release, todo, queue and every executor command are RPC-only (`src/lib/aiur/agent_control_cli.ex:13-60`).
- The only bearer plug is `AiurWeb.SupervisorAuth`, one token and one actor, on the decisions routes only (`src/lib/aiur_web/supervisor_auth.ex:18-82`, `src/lib/aiur_web/routes/decisions.ex:11-17`).
- Bearer writes on the decisions routes still pass `api_write` (Origin plus `X-Aiur-Request`, `src/lib/aiur_web/router.ex:55-58`), which a machine client can only satisfy by forging an Origin.
- No HTTP mutation records an actor (`src/lib/aiur_web/controllers/observability_api_controller.ex:60-87`).

## Scope

- Route `POST /api/v1/control` declared before the `/api/v1/:issue_identifier` catch-all (`src/lib/aiur_web/router.ex:77-102`), piped through #5945's bearer plug and `require_writable` for write scope, not `api_write`.
- Controller: authenticate first, refuse bodies over 64 KiB, then decode the KTD1 request, `Aiur.ControlCall.parse/1`, compare scope with the token's scope, `Aiur.ControlCall.run/2` with the capped timeout, respond with KTD1 result including `instance_id` (`Aiur.Identity.instance_id`, `src/lib/aiur/identity.ex:18-33`) and build version/commit.
- `Aiur.ControlCall.Audit.append/1` writes `<run-log-root>/log/control-audit.ndjson`, one line per write-scope call and per refused call:

  ```json
  {"at":"2026-10-23T18:04:11Z","token":"pc-executor","scope":"write","call":"Aiur.AgentControlCLI.set_max_agents/1","expression_sha256":"9f2c...","outcome":"ok","exit_code":0,"elapsed_ms":41,"remote_ip":"203.0.113.7"}
  ```

- `unknown_on_build` refusal: when the module/function is not exported by this build, the 422 body carries `build`.

- Docs state that a `write` token is close to full control of the instance (it can message agents and change routing) and should be stored as a 0600 file or an env secret.

## Non-goals

- Token issuance and scopes (#5945). Browser sign-in (#5611, #5942). Streaming `listen`. Remote stop/restart.

## Existing owner and reuse target

- Route-group macro pattern: `src/lib/aiur_web/routes/decisions.ex`.
- Error envelope `{error:{code,message}}`: `src/lib/aiur_web/controllers/observability_api_controller.ex:153-157`.
- Daemon-owned log root: the same root as `event-publications.ndjson` (AGENTS.md).

## Contract and invariants

Quote KTD1 verbatim from the plan. A write-scope call by a read token is 403 and is never run. A refused or failed call never returns partial output as success.

## Refreshable implementation notes

- New: `src/lib/aiur_web/routes/control.ex`, `src/lib/aiur_web/controllers/control_controller.ex`, `src/lib/aiur/control_call/audit.ex`.
- Edit: `src/lib/aiur_web/router.ex` (route order).
- Tests: `src/test/aiur_web/controllers/control_controller_test.exs`, using #5945's token fixture.

## Acceptance and verification

### Acceptance criteria

1. A read token runs `Aiur.AgentControlCLI.status()` and receives 200 with `output` ending in `__AIUR_CONTROL_EXIT__:0`.
2. A read token calling `Aiur.AgentControlCLI.set_max_agents(3)` gets 403 `scope_denied`; the cap does not change; one audit line with `outcome: "refused"` is written.
3. A write token runs it; the cap changes; one audit line with `outcome: "ok"` is written.
4. A revoked or missing token gets 401; no basic-auth fallback on this route.
5. A non-allowlisted or non-literal expression gets 422 with the reason and is audited.
6. `GET /api/v1/control` is 405 and `POST /api/v1/12345` still reaches the issue routes (route order).
7. A call exceeding its timeout returns 504 and the task is gone.

### Test that fails without the change

Controller test: POST with a read token and `Aiur.AgentControlCLI.status()` expects 200 and the exit marker; today the path hits the API's `match :*` catch-all and returns 405 (`src/lib/aiur_web/routes/api.ex:55`).

### At-merge gate

CI green; security-lens review.

### Human/manual evidence

`curl` against a local daemon with a fresh token, recorded in the PR (MIC-010 repeats on a remote instance).

## Docs to update

- `website/docs-app/reference/cli.md` "Operational facts": one row naming the control endpoint, the audit file, and that remote output equals local output.
- AGENTS.md "Per-issue workspaces" paragraph that lists daemon-owned logs: add `control-audit.ndjson`.

## Files it touches

`src/lib/aiur_web/router.ex`, `src/lib/aiur_web/routes/control.ex`, `src/lib/aiur_web/controllers/control_controller.ex`, `src/lib/aiur/control_call/audit.ex`, tests, the two docs above.

## Dependencies and conflicts

- depends_on: MIC-001 (imports `Aiur.ControlCall`), #5945 (imports the bearer plug).
- serializes_with: #5942 on `src/lib/aiur_web/router.ex` (merge-time only).

## First slice Kevin can try

With MIC-003 merged: `aiur --instance nuc status` from the PC.
