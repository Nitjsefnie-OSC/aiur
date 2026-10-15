# MP-E2-C5-T00 — R-Q2 Claude AskUserQuestion capture

Research performed 2026-10-14. Experiments changed no production code. Findings and fixtures were committed afterward at the Executor's request.

## Versions and scope

- Claude Code 2.1.299, using the existing operator login. Stream reports claude-opus-5-5[1m].
- aiur-claude 1.1.0, sibling source HEAD b1ea979c3655b0dbec13d30de6a402da26007ebd.
- Direct CLI flags match `buildClaudeArgs`: print, stream-json, verbose, include-partial-messages, bypassPermissions.
- stdlib-only stdio MCP permission host returns allow with updatedInput.answers keyed by exact question text.
- PreToolUse hook matches only AskUserQuestion. It returns defer until answer.json exists, then allow with updatedInput.answers.
- All experiments ran in a private scratch directory. Global settings and sibling checkout are not edited. Normal Claude CLI session persistence is used for resume.
- No aiur manual-TUI test claimed or needed: this is a direct CLI research spike, not a product UX change.

## Decision

**Choose Variant A: PreToolUse defer, persisted session, allow with updatedInput.answers on resume.** The mandatory 15-minute hold passed. Variant B also passed direct CLI at 10 minutes, but consumes a live process and the existing sibling dynamic-tool bridge expires at 120 seconds unless its contract changes.

The observed multi-call behavior differs from current documentation: defer is honored. This does not invalidate Variant A, but it invalidates a C5-T03 rule that infers ignored deferral merely from multiple tool calls.

Aiur checkout inspected during the spike: 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f. The subsequent artifact commit contains research evidence only.

## Status

| Question | Status | Evidence |
| --- | --- | --- |
| Q1 host needed | PASS | Baseline init tools exclude AskUserQuestion; no AskUserQuestion call; model reports it unavailable. Host control exposes it, host receives tool_name/input/tool_use_id, answer red reaches model and README. |
| Q2 defer/resume | PASS | First result is success, is_error=false, stop_reason=terminal_reason=tool_deferred, deferred_tool_use includes id/name/input. After 922.162 seconds from process exit, resume re-fires the exact same question ID and allows the supplied red answer. isolated.md contains red on two lines after Write/Read/Edit. |
| Q3 blocking host | PASS | Host sleeps 200.000 and 600.000 seconds; total CLI wall times 211.03 and 614.19 seconds. Both return red with successful results. Controlled MCP_TOOL_TIMEOUT=3000 emits permission-host timeout after 3s. |
| Q4 D10 | PASS | blocking-600 actually executes Bash, Read, Write, Edit, and AskUserQuestion; only AskUserQuestion reaches the host. Every question-matched hook record also has tool_name=AskUserQuestion. |
| Q5 documented multi-call behavior | FAIL (documentation assumption) | Read+Ask, Ask+Read, and Bash sleep 3+Ask each contain two tool_use blocks under the same assistant message ID. All exit tool_deferred, without an ignored-defer warning. The sibling tool result appears before the terminal result. |

## Adapter implications already observed

Freshly built scratch copy of the sibling, first with exact captured defer-run1 fixture replay and then with a real Claude subprocess plus scratch-only permission-host/hook flags, emits AskUserQuestion as item/created(tool_call), then turn/completed. It does not carry stop_reason or deferred_tool_use through its protocol. This is a missing capability for C5-T01, not evidence that the CLI defer mechanism fails.

The default dynamic-tools bridge sets a 120,000 ms orchestrator-response timer. A probe using the unmodified built DynamicToolBridge with no orchestrator reply returned isError=true after 120,076 ms, with text stating no orchestrator response within 120000ms. It is separate from the direct CLI stdio host, which bypasses that bridge.

## Harness corrections and limits

The inherited CLAUDE_CONFIG_DIR is outside the agent's writable sandbox. Direct runs generated deferred results but did not save the session transcript; an immediate resume returned No conversation found. This is an environment limitation, not a mechanism FAIL. A scratch-local CLAUDE_CONFIG_DIR uses the same operator login by passing the existing OAuth token in memory; no credential is printed or included in the bundle. The scratch-profile pending transcript is confirmed on disk and frozen for replay before the 15-minute resume.

An optional answered multi-call probe inherited its parent Python script on stdin with an empty -p prompt. It did not execute that snippet, but the answer result was contaminated by extra user input. The harness now disconnects stdin explicitly (DEVNULL); clean multi-call, repeated defer, and answered resume were rerun. The contaminated fixture is retained under an explicit name, excluded from the conclusions.

Clean-profile Read+Ask also defers. An immediate resume re-fires the same pending question and can defer again; a second resume with allow/answers creates isolated-clean.md containing red. This strengthens the observed multi-call result beyond the inherited-profile captures.

## Downstream contracts

- C5-T01 must add a permission host and forward deferred result metadata instead of treating it as normal completion.
- C5-T02 should load the checked-in NDJSON fixtures without further transformation. Terminal deferred results and permission-host timeout tool_result events need distinct handling; a tool timeout can still be followed by a successful overall result.
- C5-T03 must retain/recover the CLI session ID across adapter restart. The current thread map is memory-only and Aiur headless Claude declares resumable=false.
- Do not infer ignored deferral from tool-call count. Branch on the actual terminal result; 2.1.299 demonstrably defers a question in a multi-call assistant message.

## Sources consulted

These are documentation claims; experiment results above are independently observed:

- [Hooks reference](https://code.claude.com/docs/en/hooks): defer/resume and interaction-tool answer schema.
- [Handle approvals and user input](https://code.claude.com/docs/en/agent-sdk/user-input): permission host and auto-approved tools.
- [Environment variables](https://code.claude.com/docs/en/env-vars): MCP_TOOL_TIMEOUT and MCP idle timeout.
- [MCP reference](https://code.claude.com/docs/en/mcp): stdio idle default 30 minutes and overall default about 28 hours. These defaults are documented, not experimentally proven upper bounds.

## Commands and fixtures

Every run except the initial baseline has its path-redacted argument vector, exit status, timestamps, and wall time in fixtures/<name>.meta.json. The baseline command is:

```sh
claude -p 'Use the AskUserQuestion tool to ask me one question: should README.md mention red or blue? Do not guess. Then append the answer to README.md.' --output-format stream-json --verbose --include-partial-messages --permission-mode bypassPermissions
```

The 200/600-second hosts configure HOST_SLEEP in their separate MCP config files. Neither MCP_TOOL_TIMEOUT nor CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT was overridden in those runs. Only the controlled timeout probe sets MCP_TOOL_TIMEOUT=3000.

## Historical spike validation and handoff

These commands ran in the original scratch harness; they are not repository test commands.

- `python3 bin/validate.py` -> PASS. Checks real captured tool availability, terminal shape, same-ID delayed hook, elapsed hold >=900 seconds, actual red file contents, D10 host traffic, shared assistant message IDs for multi-call, repeat defer and answered clean resume, timeout errors, and the adapter forwarding gap.
- `npm --prefix adapter run build` -> PASS for both unmodified source and the scratch-only flag insertion. Source hashes and `adapter-flags.patch` are included under `fixtures/`.
- `node adapter-probe.mjs` and `node adapter-live.mjs` -> PASS for the observed forwarding gap. These verify the missing capability; they do not claim native question UI works today.
- `node bridge-timeout.mjs` -> PASS; default timeout measured at 120,076 ms.
- No production tests added; no production mutation-test or CI/PR gate applies. No product/TUI verification claimed.
- Primary session ID: `07058a6a-68df-478c-b74e-aad5171904da`; pending tool ID: `toolu_01AQq8v92P5JwLinj9JBx4LG`. Exact command vectors and timing are in metadata fixtures.
- The checked-in `fixtures/` directory contains decoded stream captures, timing metadata, pending transcript snapshots, and adapter evidence. `SHA256SUMS.json` verifies every checked-in evidence file. Personal filesystem prefixes are replaced with `/research/` placeholders. Partial JSON input deltas are coalesced into the first delta of each block so split paths can be redacted completely; later deltas in that block are empty. Event order, tool IDs, questions, answers, and terminal results are preserved. These files are normalized JSON, not byte-identical raw captures. No credentials or auth profile are included. The original scratch-only archive also holds the host/hook harness.
- Reviewer replay: use `fixtures/isolated-defer-session-before-resume.jsonl` as the pending session in a separate writable Claude profile, with the same host/settings flags and an answer keyed by the exact question text. The frozen pending transcript is supplied because the live session is already answered. Do not overwrite a live profile.
- Coordinator handoff: record R-Q2 as answered and Variant A chosen in DESIGN-E2/RQ list. C5-T01 must expose/forward the deferred result, C5-T02 consumes these normalized fixture lines, and C5-T03 must recover persisted session IDs and branch on actual terminal results for multi-call. The program design updates remain coordinator-owned.

## Artifact publication

The Executor accepted Variant A and authorized this evidence-only commit on `research/refactor-findings`. Personal path prefixes are redacted; checksums describe these committed files, not the original scratch archive. No production implementation or new automated regression tests are part of this commit.
