# RC-23 proposed-scope inventory

Main 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; U0 ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85.

Research e9785e0eef0195f86f710552200a45d2de01fdef has 130 distinct ready IDs in 251 documents. Initial 6732f5f9 census had 150 IDs including amended E6 tickets; nine present IDs are newly ready. README headline counts are historical, not live admission counts.

This inventory resolves proposed scope only. Executor must reconcile actual tracker starts, scope and publication history before claiming every admission is covered. Future starts must execute Procedure B.

## MP-E6-C10-T01

src/prompts/shared-agent-instructions.md (349), src/lib/aiur/codex/dynamic_tool/emit_event.ex (165); new status-note modules/tests must stay <=500.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C10-T02

new src/lib/aiur/voice_converse/host/briefing_source.ex and status-card modules/tests; generic rendering belongs to C11-T08 per amendment.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C10-T03

research experiment and findings only; no production source edits.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C11-T01

src/mix.exs (281), packages/elixir/voice_converse/ skeleton, .github/workflows/ci.yml (738).

CI (.github/workflows/ci.yml, 738 lines at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f, ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85).

CI workflow must remain <=738 lines; put the standalone job in a reusable workflow.

## MP-E6-C11-T02

packages/elixir/voice_converse/lib/voice_converse/wire.ex, transport/websock.ex, priv/static/voice_converse_client.js and matching tests/fixtures (new).

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C11-T03

packages/elixir/voice_converse/examples/local_host/ (new), .github/workflows/ci.yml (738) for standalone example test job.

CI (.github/workflows/ci.yml, 738 lines at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f, ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85).

CI workflow must remain <=738 lines; put the standalone job in a reusable workflow.

## MP-E6-C11-T04

src/lib/aiur.ex (286), new src/lib/aiur/voice_converse/host/ modules/tests, indexed components/*.json entries.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C11-T07

packages/elixir/voice_converse/README.md, guides, CHANGELOG, LICENSE, mix.exs ExDoc config; research birth-check.md.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500.

## MP-E6-C12-T01

src/lib/aiur/executor/claims.ex (498); new harness_session modules/tests and dedicated CLI; launcher additions must recheck their actual edited paths.

n/a (proposed edited files <=500 at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; ledger b90d65c80e2f320bc15fd9c7b30b63e791ef9a85; scope changes require recheck).

New/small files must remain <=500 lines; split additions before any small file crosses 500. claims.ex is 498 lines: at most two net lines may be added; extract the session change into a small module.

## Oversized ledger check

src/lib/aiur/orchestrator/issue_sync.ex has 2550 LF-counted lines at 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f; exact CSV row maps it to LIFECYCLE_DISPATCH. MP-R1-C6-T03 historical example src/lib/aiur.ex has 286 lines; application_test.exs has 119. APP_BOOT is not required for those current paths.
