| MP-E2-C7-T04 | — | — | "CLI (commands_cli.ex 246)" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T05 | — | — | "WEB / DECK_WEB (streamdeck_commands.ex; streamdeck_channel.ex 609 — no net growth) + packages/streamdeck" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T01 | — | — | "DOCS (concepts/commands.md 68; concepts/executor.md 32 — both small)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T02 | — | — | "DOCS (.claude/skills/aiur-run/SKILL.md 1,293 — already over 500: put new text in references/executor.md and link; net SKILL.md growth ≤ 5 lines)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T03 | — | — | "DOCS (.claude/skills/aiur-agent/attention-and-resolve.md, emit-and-subscribe.md); DECISIONS (one default literal)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T04 | — | — | "DECISIONS (config defaults) + DOCS" | NO-LONGER-OVERSIZED |
| MP-E3-C1-T02 | — | — | "U8 WEB owner (router.ex 361 lines; new controller and plug)" | NO-LONGER-OVERSIZED |
| MP-E3-C1-T03 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner (agent_control_cli.ex and aiur-engine.sh are large; add functions, do not restructure)" | MISMATCH (ledger says CLI) |
| MP-E3-C2-T01 | — | — | "n/a (new module; small option added to claude/transcript_tailer.ex, 260 lines)" | NO-LONGER-OVERSIZED |
| MP-E3-C4-T05 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner (agent_control_cli.ex)" | MISMATCH (ledger says CLI) |
| MP-E3-C6-T01 | — | — | "U8 WEB owner (new LiveView; dashboard_live.ex 2,903 lines must not grow beyond a nav link)" | NO-LONGER-OVERSIZED |
| MP-E3-C6-T02 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E3-C6-T03 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E3-C7-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner" | MISMATCH (ledger says CLI) |
| MP-E4-C1-T03 | src/lib/aiur/agent_runner/message_handler.ex | 671 | "U8 RUN owner (message_handler.ex 671 lines, session_lifecycle.ex: keep net additions small)" | MISMATCH (ledger says AGENT_TURN) |
| MP-E4-C2-T02 | — | — | "U8 WEB owner (router.ex 361 lines)" | NO-LONGER-OVERSIZED |
| MP-E4-C4-T02 | src/lib/aiur/agent_runner/tool_executor.ex | 889 | "U8 WEB owner (decision_detail.ex 164 lines; no dashboard_live.ex growth)" | MISMATCH (ledger says AGENT_TURN) |
| MP-E4-C5-T01 | — | — | "U8 WEB owner (new LiveView; dashboard_live.ex 2,903 lines must not grow)" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T02 | — | — | "U8 WEB owner (new component module)" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T03 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T04 | — | — | "U8 WEB owner (conversation_drawer.ex 276 lines; dashboard_live.ex must not grow beyond the link assign)" | NO-LONGER-OVERSIZED |
| MP-E4-C6-T01 | — | — | "U8 WEB owner (new component; no dashboard_live.ex growth)" | NO-LONGER-OVERSIZED |
| MP-E4-C6-T02 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E4-C7-T01 | — | — | "U8 SD owner (streamdeck_logs.ex 637 lines; this ticket reduces or keeps it)" | NO-LONGER-OVERSIZED |
| MP-E5-C1-T01 | — | — | WEB (conversation_drawer.ex is 276 lines; no split needed) | NO-LONGER-OVERSIZED |
| MP-E5-C1-T02 | src/priv/static/conversation-voice-controller.js | 539 | BROWSER (conversation-voice-controller.js, 539 lines, over the 500-line U8 ceiling) | MISMATCH (ledger says BROWSER) |
| MP-E5-C1-T03 | — | — | BROWSER (layouts.ex is 336 lines; new hook file is small) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T01 | — | — | WEB (voice_channel.ex is 331 lines; target validation goes to a new module) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T02 | — | — | WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T03 | — | — | WEB (dashboard_live.ex 2,903 lines — the change is net-neutral: one assign line; logic lives in a new module) | NO-LONGER-OVERSIZED |
| MP-E5-C3-T01 | — | — | BROWSER (controller), WEB (component) | NO-LONGER-OVERSIZED |
| MP-E5-C3-T02 | — | — | WEB | NO-LONGER-OVERSIZED |
| MP-E5-C3-T03 | — | — | BROWSER (controller), WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C4-T01 | — | — | WEB (decision_action.ex is 198 lines) | NO-LONGER-OVERSIZED |
| MP-E5-C4-T02 | — | — | WEB (decision_revision_action.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C5-T01 | — | — | WEB (agent_log_modal.ex is 181 lines) | NO-LONGER-OVERSIZED |
| MP-E5-C6-T01 | — | — | BROWSER (conversation-voice-controller.js after the C1-T02 split) | NO-LONGER-OVERSIZED |
| MP-E5-C6-T02 | — | — | BROWSER | NO-LONGER-OVERSIZED |
| MP-E5-C6-T03 | — | — | WEB | NO-LONGER-OVERSIZED |
| MP-E5-C8-T01 | — | — | WEB (router.ex, endpoint.ex; new modules are small) | NO-LONGER-OVERSIZED |
| MP-E5-C8-T02 | — | — | WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E6-C11-T05 | — | — | harness adapter files per MP-R7 (each adapter + one new fork_replay.ex) | NO-LONGER-OVERSIZED |
| MP-E6-C2-T04 | src/lib/aiur/alerts.ex | 762 | n/a (new file) | MISMATCH (ledger says EVENTS) |
| MP-E6-C3-T02 | — | — | launcher (aiur-engine.sh, 4,260 lines — add one dispatch case and one small cmd function) | NO-LONGER-OVERSIZED |
| MP-E6-C6-T03 | — | — | launcher (aiur-engine.sh — one subcommand in cmd_voice) | NO-LONGER-OVERSIZED |
| MP-E6-C7-T04 | — | — | BROWSER | NO-LONGER-OVERSIZED |
| MP-E7-C1-T03 | .github/workflows/release-npm.yml | 600 | n/a (Khala repository) | MISMATCH (ledger says CI) |
| MP-E7-C1-T04 | .github/workflows/ci.yml | 738 | n/a (new files only, each < 200 lines) | MISMATCH (ledger says CI) |
| MP-E7-C2-T01 | src/lib/aiur/agent_queue_store.ex | 597 | n/a for new files; LIFECYCLE_DISPATCH for the 2-line hook in orchestrator/workspace_cleanup.ex (165 lines) | MISMATCH (ledger says AGENT_TURN) |
| MP-E7-C2-T01 | src/lib/aiur/orchestrator/state.ex | 1025 | n/a for new files; LIFECYCLE_DISPATCH for the 2-line hook in orchestrator/workspace_cleanup.ex (165 lines) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E7-C2-T03 | src/lib/aiur/orchestrator.ex | 956 | LIFECYCLE_DISPATCH (orchestrator.ex 1,003 lines: +6 lines of delegating handle_call clauses only; logic in a new module) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E7-C2-T04 | — | — | LIFECYCLE_DISPATCH (orchestrator/state.ex 1,033 lines: one call added in put_session_execution/4; logic in orchestrator/listener_modes.ex) | NO-LONGER-OVERSIZED |
| MP-E7-C2-T05 | src/lib/aiur/events/publisher.ex | 539 | n/a (orchestrator/listener_modes.ex, new; no growth of EVENTS paths) | MISMATCH (ledger says EVENTS) |
| MP-E7-C3-T01 | src/test/aiur/agent_queue_test.exs | 538 | AGENT_TURN (agent_queue_store.ex, 597 lines: ≤ 25 added lines, no new responsibilities; agent_queue.ex 54 lines) | MISMATCH (ledger says AGENT_TURN) |
| MP-E7-C3-T02 | — | — | LIFECYCLE_DISPATCH (operator_messages.ex 1,167 lines: ≤ 20 lines — the :listener branch and the checkpoint-matcher exclusion; delivery_policy.ex 186 lines) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T02 | — | — | AGENT_TURN (app_server/*), CODEX (codex/*) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T03 | — | — | AGENT_TURN (muse/* has no dedicated U8 owner; files are < 500 lines) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T04 | — | — | CLAUDE | NO-LONGER-OVERSIZED |
| MP-E7-C5-T01 | — | — | AGENT_CORE (agent tool surface) | NO-LONGER-OVERSIZED |
| MP-E7-C5-T02 | — | — | ORCH (operator_messages/*) | NO-LONGER-OVERSIZED |
| MP-E7-C5-T03 | — | — | ORCH | NO-LONGER-OVERSIZED |
| MP-E7-C5-T04 | — | — | AGENT_TURN (turn prompt) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T01 | — | — | WEB (observability_api_controller is oversized — new controller module) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T02 | — | — | CLAUDE (hook command generation) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T03 | — | — | EXE (executor attach CLI, MP-E3 owner) | NO-LONGER-OVERSIZED |
| MP-E7-C7-T01 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | WEB (dashboard_live.ex is 2,903 lines — new component module only) | MISMATCH (ledger says WEB) |
| MP-E7-C7-T02 | — | — | TUI (agent_list/*) | NO-LONGER-OVERSIZED |
| MP-E7-C7-T03 | src/test/aiur/agent_control_cli_test.exs | 3766 | CTL (agent_control_cli.ex is 3,482 lines — new module only) | MISMATCH (ledger says CLI) |
| MP-E7-C7-T04 | — | — | MSG | NO-LONGER-OVERSIZED |
| MP-E8-C1-T02 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C11-T01 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T02 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T05 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T06 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C12-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C12-T02 | website/public/images/dashboard/build-orders-dark.png | 910 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C12-T04 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C12-T06 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C12-T07 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C12-T07 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C12-T08 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C13-T00 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T00 | src/lib/aiur/github/budget.ex | 928 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T00 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T01 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T01 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T01 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C13-T01 | src/lib/aiur/github/resource_store.ex | 2217 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T01 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T02 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T02 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T02 | src/lib/aiur/github/budget.ex | 928 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T02 | src/lib/aiur/progress_retention.ex | 532 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C13-T02 | src/test/aiur/agent_control_cli_test.exs | 3766 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T03 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T04 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T04 | src/lib/aiur/agent_runner/tool_executor.ex | 889 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C13-T04 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C13-T04 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C14-T02 | src/lib/aiur/agent_queue_store.ex | 597 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C2-T03 | src/test/aiur/extensions_test.exs | 1925 |  | MISMATCH (ledger says TEST_HARNESS) |
| MP-E8-C2-T03 | website/public/assets/aiur-logo.png | 2097 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C3-T02 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C3-T03 | src/test/fixtures/build_home/design-source/assets/build.js | 1577 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C4-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C4-T03 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C4-T03 | src/lib/aiur/github/resource_store.ex | 2217 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C4-T03 | src/lib/aiur/github/transport.ex | 854 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C4-T03 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C5-T01 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T01 | src/lib/aiur/workflow_store.ex | 542 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C5-T01 | src/test/aiur/core_test.exs | 4169 |  | MISMATCH (ledger says TEST_HARNESS) |
| MP-E8-C5-T02 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C5-T02 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T03 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C5-T03 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C5-T03 | src/lib/aiur/agent_runner/tool_executor.ex | 889 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C5-T03 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C5-T03 | src/lib/aiur/progress_retention.ex | 532 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C5-T03 | src/test/aiur/agent_runner/tool_executor_test.exs | 1964 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C5-T04 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T04 | src/test/aiur/aiur_agent_skill_test.exs | 876 |  | MISMATCH (ledger says SKILLS) |
| MP-E8-C6-T02 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C6-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C7-T02 | src/priv/build_orders/aiur-build-order.json | 729 |  | MISMATCH (ledger says BO_PUBLISH) |
| MP-E8-C8-T01 | src/test/fixtures/build_home/design-source/assets/build.js | 1577 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C8-T04 | src/lib/aiur/github/config.ex | 1089 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C8-T04 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C9-T03 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-N1-C1-T01 | packages/streamdeck/package-lock.json | 3028 | n/a (new package; no U8 ledger row) | MISMATCH (ledger says DECK_PKG) |
| MP-N1-C3-T04 | src/lib/aiur/orchestrator.ex | 956 | n/a (new package) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-N1-C4-T04 | src/priv/static/conversation-voice-controller.js | 539 | "U8 ledger owner of src/lib/aiur_web/components/layouts.ex (U6 scope src/lib/aiur_web/)" | MISMATCH (ledger says BROWSER) |
| MP-N1-C4-T05 | src/priv/static/conversation-voice-controller.js | 539 | n/a (new package) | MISMATCH (ledger says BROWSER) |
| MP-N1-C8-T01 | .github/workflows/release-npm.yml | 600 | n/a (script + docs) | MISMATCH (ledger says CI) |
| MP-N2-C10-T01 | — | — | "WEB (U8 ledger; look up the owner of http_server.ex and router.ex at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T02 | — | — | "n/a (new gateway modules); launcher lines in aiur-engine.sh are shared with U1/U9 — recheck at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T03 | — | — | "launcher dispatch in aiur-engine.sh (U1/U9 share the file; recheck lines at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T04 | — | — | "WEB (endpoint.ex); look up at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C2-T01 | — | — | "aiur.ex child list (U8 ledger owner of src/lib/aiur.ex; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C2-T02 | — | — | "shutdown.ex (U8 ledger owner; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C3-T02 | — | — | "aiur-engine.sh and cli.ex (U1/U9 share the engine; look up owners at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C3-T04 | — | — | "init.ex (INI; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C4-T01 | — | — | "cli.ex (U8 ledger owner; look up at the implementation SHA); new modules n/a" | NO-LONGER-OVERSIZED |
| MP-N2-C4-T02 | — | — | "aiur-engine.sh (shared with U1/U9; recheck line numbers at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C5-T01 | — | — | "n/a (new modules under src/lib/aiur/machine/); launcher dispatch lines shared with U1/U9 — recheck at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C5-T02 | src/lib/aiur/alerts.ex | 762 | n/a (new gateway modules) | MISMATCH (ledger says EVENTS) |
| MP-N2-C6-T01 | — | — | "WEB — router.ex is in the U8 ledger (MP-N2-C6 named there); look up the owner at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C6-T02 | — | — | "WEB — financial_data_access.ex / proof.ex / router.ex; look up U8 owners at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C6-T03 | — | — | "WEB — router.ex (U8 ledger); look up at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C7-T01 | — | — | "n/a (new modules); engine dispatch lines shared with U1/U9" | NO-LONGER-OVERSIZED |
| MP-N2-C8-T02 | — | — | "WEB — router.ex and a new LiveView module (do not grow dashboard_live.ex, 2,903 lines, per U8)" | NO-LONGER-OVERSIZED |
| MP-N2-C9-T01 | — | — | "SITE/DOCS (U8 ledger)" | NO-LONGER-OVERSIZED |
| MP-N3-C1-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "n/a (new module; PRJ boundary owner per U8 ledger at implementation time)" | MISMATCH (ledger says CLI) |
| MP-N3-C1-T02 | src/lib/aiur/orchestrator.ex | 956 | "n/a (new provider module)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-N3-C1-T03 | src/test/aiur/decision_query_test.exs | 809 | "n/a (new provider module; DecisionQuery is read only)" | MISMATCH (ledger says DECISIONS) |
| MP-N3-C1-T04 | — | — | "n/a (new provider module)" | NO-LONGER-OVERSIZED |
| MP-N3-C1-T05 | — | — | "n/a (new provider module)" | NO-LONGER-OVERSIZED |
| MP-N3-C2-T01 | — | — | "n/a (new gateway module)" | NO-LONGER-OVERSIZED |
| MP-N3-C2-T02 | — | — | "n/a (new gateway module)" | NO-LONGER-OVERSIZED |
| MP-N4-C1-T01 | .github/workflows/release-npm.yml | 600 | n/a | MISMATCH (ledger says CI) |
| MP-N4-C2-T05 | website/docs-app/apis/github.md | 820 | n/a | MISMATCH (ledger says DOCS) |
| MP-N4-C2-T07 | website/docs-app/apis/github.md | 820 | n/a | MISMATCH (ledger says DOCS) |
| MP-N4-C3-T02 | src/lib/aiur/decision_store.ex | 4989 | n/a | MISMATCH (ledger says DECISIONS) |
| MP-N4-C3-T07 | src/lib/aiur/agent_control_cli.ex | 2898 | aiur-engine.sh / agent_control_cli.ex owners per U8 ledger | MISMATCH (ledger says CLI) |
| MP-N4-C3-T07 | src/test/aiur/agent_control_cli_test.exs | 3766 | aiur-engine.sh / agent_control_cli.ex owners per U8 ledger | MISMATCH (ledger says CLI) |
| MP-N5-C1-T03 | — | — | router.ex — web-shell owner per U8 ledger | NO-LONGER-OVERSIZED |
| MP-N6-C1-T01 | — | — | router.ex — web-shell owner per U8 ledger | NO-LONGER-OVERSIZED |
| MP-E1-C1-T01 | src/lib/aiur/github/issues.ex | 1239 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, re-check per RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T02 | src/lib/aiur/github/issues.ex | 1239 | "LIFECYCLE_DISPATCH / Ticket lifecycle and dispatch (orchestrator/issue_sync.ex, 2295 lines; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T02 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 | "LIFECYCLE_DISPATCH / Ticket lifecycle and dispatch (orchestrator/issue_sync.ex, 2295 lines; provisional, RC-23)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E1-C1-T02 | src/test/aiur/orchestrator/issue_sync_test.exs | 3223 | "LIFECYCLE_DISPATCH / Ticket lifecycle and dispatch (orchestrator/issue_sync.ex, 2295 lines; provisional, RC-23)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E1-C1-T03 | src/test/aiur/github/issues_test.exs | 1506 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T03 | website/docs-app/apis/github.md | 820 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, RC-23)" | MISMATCH (ledger says DOCS) |
| MP-E1-C1-T04 | src/test/aiur/github/issue_state_test.exs | 611 | "GH_TRUST / GitHub access (github/issue_state.ex; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T05 | — | — | "LIFECYCLE_DISPATCH / Ticket lifecycle and dispatch (orchestrator/dispatch_policy.ex, 1213 lines; provisional, RC-23)" | NO-LONGER-OVERSIZED |
| MP-E1-C1-T06 | — | — | "LIFECYCLE_DISPATCH / Ticket lifecycle and dispatch (orchestrator.ex, 1003 lines; provisional, RC-23)" | NO-LONGER-OVERSIZED |
| MP-E1-C3-T01 | — | — | "CONFIG / Configuration (config.ex 1462 lines, not edited); config/schema.ex small (provisional, RC-23)" | NO-LONGER-OVERSIZED |
| MP-E1-C3-T03 | — | — | "APP_BOOT / Repository support (src/lib/aiur.ex, 600 lines; provisional, RC-23)" | NO-LONGER-OVERSIZED |
| MP-E1-C3-T04 | website/docs-app/apis/github.md | 820 | "GH_TRUST (github/tracker.ex, small addition; provisional, RC-23)" | MISMATCH (ledger says DOCS) |
| MP-E1-C3-T08 | — | — | "new file; one line in src/config/config.exs (composition root); provisional, RC-23" | NO-LONGER-OVERSIZED |
| MP-E1-C4-T03 | website/docs-app/apis/github.md | 820 | "GH_TRUST (github/tracker.ex small addition; provisional, RC-23)" | MISMATCH (ledger says DOCS) |
| MP-E1-C4-T04 | src/lib/aiur/github/issues.ex | 1239 | "GH_TRUST (github/issues.ex 1248 lines, one-line change; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C4-T04 | src/test/aiur/github/issues_test.exs | 1506 | "GH_TRUST (github/issues.ex 1248 lines, one-line change; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C4-T04 | website/docs-app/apis/github.md | 820 | "GH_TRUST (github/issues.ex 1248 lines, one-line change; provisional, RC-23)" | MISMATCH (ledger says DOCS) |
| MP-E1-C4-T05 | — | — | "GH_TRUST (github/tracker.ex small addition; provisional, RC-23)" | NO-LONGER-OVERSIZED |
| MP-E1-C6-T01 | src/test/aiur/agent_control_cli_test.exs | 3766 | "CLI / npm CLI packaging (aiur-engine.sh 4224 lines) and Agent control CLI (agent_control_cli.ex 3362 lines); provisional, RC-23" | MISMATCH (ledger says CLI) |
| MP-E1-C6-T02 | — | — | "CLI (aiur-engine.sh, agent_control_cli.ex); provisional, RC-23" | NO-LONGER-OVERSIZED |
| MP-E1-C6-T03 | — | — | "CLI (aiur-engine.sh); provisional, RC-23" | NO-LONGER-OVERSIZED |
| MP-E1-C7-T01 | — | — | "APP_BOOT (src/lib/aiur.ex one child line); new file otherwise; provisional, RC-23" | NO-LONGER-OVERSIZED |
| MP-E1-C9-T04 | website/docs-app/apis/github.md | 820 | n/a (measurement) | MISMATCH (ledger says DOCS) |
| MP-E2-C1-T01 | src/lib/aiur/decision_event.ex | 1056 | "DECISIONS (decision_store.ex 4,826; decision_projection.ex 1,039; decision_event.ex 1,057) — one delegating clause per file only" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T01 | src/lib/aiur/decision_projection.ex | 1039 | "DECISIONS (decision_store.ex 4,826; decision_projection.ex 1,039; decision_event.ex 1,057) — one delegating clause per file only" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T01 | src/lib/aiur/decision_store.ex | 4989 | "DECISIONS (decision_store.ex 4,826; decision_projection.ex 1,039; decision_event.ex 1,057) — one delegating clause per file only" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T01 | src/test/aiur/decision_store_test.exs | 4847 | "DECISIONS (decision_store.ex 4,826; decision_projection.ex 1,039; decision_event.ex 1,057) — one delegating clause per file only" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T02 | — | — | "DECISIONS (decision_validation.ex 494 — must stay ≤ 500; new logic in commands/request_content.ex)" | NO-LONGER-OVERSIZED |
| MP-E2-C1-T03 | src/lib/aiur/decision_store.ex | 4989 | "DECISIONS (decision_store.ex — two call sites replaced, no growth)" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T03 | src/lib/aiur/executor_events.ex | 559 | "DECISIONS (decision_store.ex — two call sites replaced, no growth)" | MISMATCH (ledger says EVENTS) |
| MP-E2-C1-T04 | src/lib/aiur/decision_projection.ex | 1039 | "DECISIONS (decision_api/public_projection.ex 114) + WEB (decision_presenter.ex 168); both stay small" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C1-T04 | src/test/aiur/decision_api_test.exs | 964 | "DECISIONS (decision_api/public_projection.ex 114) + WEB (decision_presenter.ex 168); both stay small" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C2-T01 | — | — | "n/a — new module (≤ 200 lines)" | NO-LONGER-OVERSIZED |
| MP-E2-C2-T02 | — | — | "DECISIONS (decision_store.ex: one public fn + one handle_call; decision_event.ex / decision_projection.ex: list extension only)" | NO-LONGER-OVERSIZED |
| MP-E2-C2-T03 | — | — | "n/a for the new module; DECISIONS for the one-guard edit in decision_store.ex handle_defer" | NO-LONGER-OVERSIZED |
| MP-E2-C2-T04 | src/lib/aiur/agent_control_cli.ex | 2898 | "CLI (aiur-engine.sh; agent_control_cli.ex 3,482 — 4-line delegator only) + DECISIONS (executor_command_cli.ex 387)" | MISMATCH (ledger says CLI) |
| MP-E2-C2-T05 | — | — | "DECISIONS (config/schema/decisions.ex 62; config.ex 1,471 — accessor lines only) + DOCS (configuration.md)" | NO-LONGER-OVERSIZED |
| MP-E2-C3-T01 | src/lib/aiur/decision_event.ex | 1056 | "DECISIONS (decision_store.ex — one guard call in handle_revision/4, actor_source in normalize_actor)" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C3-T01 | src/lib/aiur/decision_store.ex | 4989 | "DECISIONS (decision_store.ex — one guard call in handle_revision/4, actor_source in normalize_actor)" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C3-T01 | src/test/aiur/decision_withdrawal_test.exs | 594 | "DECISIONS (decision_store.ex — one guard call in handle_revision/4, actor_source in normalize_actor)" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C3-T02 | — | — | "n/a — new module; WEB untouched here (C3-T03 wires the dashboard)" | NO-LONGER-OVERSIZED |
| MP-E2-C3-T03 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | "WEB (decision_commands.ex 386; decision_action.ex 198; decision_revision_action.ex) — no file may pass 500" | MISMATCH (ledger says WEB) |
| MP-E2-C3-T04 | — | — | "WEB / DECK_WEB (streamdeck_channel.ex 609 — already over 500: net growth must be ≤ 0, move helpers out) + packages/streamdeck" | NO-LONGER-OVERSIZED |
| MP-E2-C4-T01 | — | — | "n/a — new module (≤ 200 lines)" | NO-LONGER-OVERSIZED |
| MP-E2-C4-T02 | — | — | "CODEX (codex/approvals.ex 356 — one call site); AGENT_CORE (app_server/turn_loop.ex 152); LIFECYCLE (runtime_watchdog.ex 376, token_accounting.ex) — guard lines only" | NO-LONGER-OVERSIZED |
| MP-E2-C4-T03 | — | — | "DECISIONS (decision_dispatch.ex 108); AGENT_CORE (checkpoint_delivery.ex 235, turn_callbacks.ex, app_server/interrupts.ex 76)" | NO-LONGER-OVERSIZED |
| MP-E2-C4-T04 | — | — | "AGENT_CORE (app_server/turn_loop.ex 152; app_server/interrupts.ex 76) — small guards; logic in commands/native_capture/release.ex" | NO-LONGER-OVERSIZED |
| MP-E2-C4-T05 | — | — | "CODEX (codex/config.ex 126; codex/app_server_port.ex 287)" | NO-LONGER-OVERSIZED |
| MP-E2-C5-T01 | — | — | "n/a — external repo its-everdred/claude-app-server (src/server.ts 42 KB; add a new module)" | NO-LONGER-OVERSIZED |
| MP-E2-C5-T02 | — | — | "CLAUDE (claude/coding_agent.ex 534 — already over 500: add one delegating clause, move ≥ equal lines out or coordinate with the U8 CLAUDE owner)" | NO-LONGER-OVERSIZED |
| MP-E2-C5-T03 | src/lib/aiur/decision_store.ex | 4989 | "n/a — logic in commands/native_capture/claude.ex and the sibling module" | MISMATCH (ledger says DECISIONS) |
| MP-E2-C6-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "CLI (aiur-engine.sh; agent_control_cli.ex 3,482 — delegator only); DECISIONS (one guard in decision_store.ex executor answer policy)" | MISMATCH (ledger says CLI) |
| MP-E2-C6-T02 | src/lib/aiur/executor_events.ex | 559 | "U3 owner for executor_listener.ex / executor_wake_projection.ex (narrow allowlist only); DECISIONS (one dispatchability guard; decision.ex delivered?/1)" | MISMATCH (ledger says EVENTS) |
| MP-E2-C6-T02 | src/lib/aiur/executor_wake_inbox.ex | 618 | "U3 owner for executor_listener.ex / executor_wake_projection.ex (narrow allowlist only); DECISIONS (one dispatchability guard; decision.ex delivered?/1)" | MISMATCH (ledger says EVENTS) |
| MP-E2-C6-T03 | — | — | "CLI (asks_cli.ex, aiur-engine.sh run_asks)" | NO-LONGER-OVERSIZED |
| MP-E2-C6-T04 | — | — | "WEB (decision_inbox.ex 154; decision_card.ex 244; units_filters)" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T01 | — | — | "WEB (decision_inbox.ex 154; overview.ex 173; fleet_table.ex 194; decision_card.ex 244)" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T02 | — | — | "WEB (decision_detail.ex 164; decision_action.ex 198; history.ex 300) — new components for the timeline and the multi-question form" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T03 | — | — | "WEB (units_table.ex 412; units_presenter.ex; units_policy.ex); LIFECYCLE (status_report.ex — one field)" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T04 | — | — | "CLI (commands_cli.ex 246)" | NO-LONGER-OVERSIZED |
| MP-E2-C7-T05 | — | — | "WEB / DECK_WEB (streamdeck_commands.ex; streamdeck_channel.ex 609 — no net growth) + packages/streamdeck" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T01 | — | — | "DOCS (concepts/commands.md 68; concepts/executor.md 32 — both small)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T02 | — | — | "DOCS (.claude/skills/aiur-run/SKILL.md 1,293 — already over 500: put new text in references/executor.md and link; net SKILL.md growth ≤ 5 lines)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T03 | — | — | "DOCS (.claude/skills/aiur-agent/attention-and-resolve.md, emit-and-subscribe.md); DECISIONS (one default literal)" | NO-LONGER-OVERSIZED |
| MP-E2-C8-T04 | — | — | "DECISIONS (config defaults) + DOCS" | NO-LONGER-OVERSIZED |
| MP-E3-C1-T02 | — | — | "U8 WEB owner (router.ex 361 lines; new controller and plug)" | NO-LONGER-OVERSIZED |
| MP-E3-C1-T03 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner (agent_control_cli.ex and aiur-engine.sh are large; add functions, do not restructure)" | MISMATCH (ledger says CLI) |
| MP-E3-C2-T01 | — | — | "n/a (new module; small option added to claude/transcript_tailer.ex, 260 lines)" | NO-LONGER-OVERSIZED |
| MP-E3-C4-T05 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner (agent_control_cli.ex)" | MISMATCH (ledger says CLI) |
| MP-E3-C6-T01 | — | — | "U8 WEB owner (new LiveView; dashboard_live.ex 2,903 lines must not grow beyond a nav link)" | NO-LONGER-OVERSIZED |
| MP-E3-C6-T02 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E3-C6-T03 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E3-C7-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "U8 CLI owner" | MISMATCH (ledger says CLI) |
| MP-E4-C1-T03 | src/lib/aiur/agent_runner/message_handler.ex | 671 | "U8 RUN owner (message_handler.ex 671 lines, session_lifecycle.ex: keep net additions small)" | MISMATCH (ledger says AGENT_TURN) |
| MP-E4-C2-T02 | — | — | "U8 WEB owner (router.ex 361 lines)" | NO-LONGER-OVERSIZED |
| MP-E4-C4-T02 | src/lib/aiur/agent_runner/tool_executor.ex | 889 | "U8 WEB owner (decision_detail.ex 164 lines; no dashboard_live.ex growth)" | MISMATCH (ledger says AGENT_TURN) |
| MP-E4-C5-T01 | — | — | "U8 WEB owner (new LiveView; dashboard_live.ex 2,903 lines must not grow)" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T02 | — | — | "U8 WEB owner (new component module)" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T03 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E4-C5-T04 | — | — | "U8 WEB owner (conversation_drawer.ex 276 lines; dashboard_live.ex must not grow beyond the link assign)" | NO-LONGER-OVERSIZED |
| MP-E4-C6-T01 | — | — | "U8 WEB owner (new component; no dashboard_live.ex growth)" | NO-LONGER-OVERSIZED |
| MP-E4-C6-T02 | — | — | "U8 WEB owner" | NO-LONGER-OVERSIZED |
| MP-E4-C7-T01 | — | — | "U8 SD owner (streamdeck_logs.ex 637 lines; this ticket reduces or keeps it)" | NO-LONGER-OVERSIZED |
| MP-E5-C1-T01 | — | — | WEB (conversation_drawer.ex is 276 lines; no split needed) | NO-LONGER-OVERSIZED |
| MP-E5-C1-T02 | src/priv/static/conversation-voice-controller.js | 539 | BROWSER (conversation-voice-controller.js, 539 lines, over the 500-line U8 ceiling) | MISMATCH (ledger says BROWSER) |
| MP-E5-C1-T03 | — | — | BROWSER (layouts.ex is 336 lines; new hook file is small) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T01 | — | — | WEB (voice_channel.ex is 331 lines; target validation goes to a new module) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T02 | — | — | WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C2-T03 | — | — | WEB (dashboard_live.ex 2,903 lines — the change is net-neutral: one assign line; logic lives in a new module) | NO-LONGER-OVERSIZED |
| MP-E5-C3-T01 | — | — | BROWSER (controller), WEB (component) | NO-LONGER-OVERSIZED |
| MP-E5-C3-T02 | — | — | WEB | NO-LONGER-OVERSIZED |
| MP-E5-C3-T03 | — | — | BROWSER (controller), WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C4-T01 | — | — | WEB (decision_action.ex is 198 lines) | NO-LONGER-OVERSIZED |
| MP-E5-C4-T02 | — | — | WEB (decision_revision_action.ex) | NO-LONGER-OVERSIZED |
| MP-E5-C5-T01 | — | — | WEB (agent_log_modal.ex is 181 lines) | NO-LONGER-OVERSIZED |
| MP-E5-C6-T01 | — | — | BROWSER (conversation-voice-controller.js after the C1-T02 split) | NO-LONGER-OVERSIZED |
| MP-E5-C6-T02 | — | — | BROWSER | NO-LONGER-OVERSIZED |
| MP-E5-C6-T03 | — | — | WEB | NO-LONGER-OVERSIZED |
| MP-E5-C8-T01 | — | — | WEB (router.ex, endpoint.ex; new modules are small) | NO-LONGER-OVERSIZED |
| MP-E5-C8-T02 | — | — | WEB (voice_channel.ex) | NO-LONGER-OVERSIZED |
| MP-E6-C2-T04 | src/lib/aiur/alerts.ex | 762 | n/a (new file) | MISMATCH (ledger says EVENTS) |
| MP-E6-C3-T02 | — | — | launcher (aiur-engine.sh, 4,260 lines — add one dispatch case and one small cmd function) | NO-LONGER-OVERSIZED |
| MP-E6-C6-T03 | — | — | launcher (aiur-engine.sh — one subcommand in cmd_voice) | NO-LONGER-OVERSIZED |
| MP-E6-C7-T04 | — | — | BROWSER | NO-LONGER-OVERSIZED |
| MP-E7-C1-T03 | .github/workflows/release-npm.yml | 600 | n/a (Khala repository) | MISMATCH (ledger says CI) |
| MP-E7-C1-T04 | .github/workflows/ci.yml | 738 | n/a (new files only, each < 200 lines) | MISMATCH (ledger says CI) |
| MP-E7-C2-T01 | src/lib/aiur/agent_queue_store.ex | 597 | n/a for new files; LIFECYCLE_DISPATCH for the 2-line hook in orchestrator/workspace_cleanup.ex (165 lines) | MISMATCH (ledger says AGENT_TURN) |
| MP-E7-C2-T01 | src/lib/aiur/orchestrator/state.ex | 1025 | n/a for new files; LIFECYCLE_DISPATCH for the 2-line hook in orchestrator/workspace_cleanup.ex (165 lines) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E7-C2-T03 | src/lib/aiur/orchestrator.ex | 956 | LIFECYCLE_DISPATCH (orchestrator.ex 1,003 lines: +6 lines of delegating handle_call clauses only; logic in a new module) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E7-C2-T04 | — | — | LIFECYCLE_DISPATCH (orchestrator/state.ex 1,033 lines: one call added in put_session_execution/4; logic in orchestrator/listener_modes.ex) | NO-LONGER-OVERSIZED |
| MP-E7-C2-T05 | src/lib/aiur/events/publisher.ex | 539 | n/a (orchestrator/listener_modes.ex, new; no growth of EVENTS paths) | MISMATCH (ledger says EVENTS) |
| MP-E7-C3-T01 | src/test/aiur/agent_queue_test.exs | 538 | AGENT_TURN (agent_queue_store.ex, 597 lines: ≤ 25 added lines, no new responsibilities; agent_queue.ex 54 lines) | MISMATCH (ledger says AGENT_TURN) |
| MP-E7-C3-T02 | — | — | LIFECYCLE_DISPATCH (operator_messages.ex 1,167 lines: ≤ 20 lines — the :listener branch and the checkpoint-matcher exclusion; delivery_policy.ex 186 lines) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T02 | — | — | AGENT_TURN (app_server/*), CODEX (codex/*) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T03 | — | — | AGENT_TURN (muse/* has no dedicated U8 owner; files are < 500 lines) | NO-LONGER-OVERSIZED |
| MP-E7-C4-T04 | — | — | CLAUDE | NO-LONGER-OVERSIZED |
| MP-E7-C5-T01 | — | — | AGENT_CORE (agent tool surface) | NO-LONGER-OVERSIZED |
| MP-E7-C5-T02 | — | — | ORCH (operator_messages/*) | NO-LONGER-OVERSIZED |
| MP-E7-C5-T03 | — | — | ORCH | NO-LONGER-OVERSIZED |
| MP-E7-C5-T04 | — | — | AGENT_TURN (turn prompt) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T01 | — | — | WEB (observability_api_controller is oversized — new controller module) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T02 | — | — | CLAUDE (hook command generation) | NO-LONGER-OVERSIZED |
| MP-E7-C6-T03 | — | — | EXE (executor attach CLI, MP-E3 owner) | NO-LONGER-OVERSIZED |
| MP-E7-C7-T01 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | WEB (dashboard_live.ex is 2,903 lines — new component module only) | MISMATCH (ledger says WEB) |
| MP-E7-C7-T02 | — | — | TUI (agent_list/*) | NO-LONGER-OVERSIZED |
| MP-E7-C7-T03 | src/test/aiur/agent_control_cli_test.exs | 3766 | CTL (agent_control_cli.ex is 3,482 lines — new module only) | MISMATCH (ledger says CLI) |
| MP-E7-C7-T04 | — | — | MSG | NO-LONGER-OVERSIZED |
| MP-E8-C1-T02 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C11-T01 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T02 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T05 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C11-T06 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C12-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C12-T02 | website/public/images/dashboard/build-orders-dark.png | 910 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C12-T04 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C12-T06 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C12-T07 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C12-T07 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C12-T08 | .github/workflows/ci.yml | 738 |  | MISMATCH (ledger says CI) |
| MP-E8-C13-T00 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T00 | src/lib/aiur/github/budget.ex | 928 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T00 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T01 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T01 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T01 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C13-T01 | src/lib/aiur/github/resource_store.ex | 2217 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T01 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T02 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T02 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T02 | src/lib/aiur/github/budget.ex | 928 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C13-T02 | src/lib/aiur/progress_retention.ex | 532 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C13-T02 | src/test/aiur/agent_control_cli_test.exs | 3766 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C13-T03 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C13-T04 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C13-T04 | src/lib/aiur/agent_runner/tool_executor.ex | 889 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C13-T04 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C13-T04 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C14-T02 | src/lib/aiur/agent_queue_store.ex | 597 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C2-T03 | src/test/aiur/extensions_test.exs | 1925 |  | MISMATCH (ledger says TEST_HARNESS) |
| MP-E8-C2-T03 | website/public/assets/aiur-logo.png | 2097 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C3-T02 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C3-T03 | src/test/fixtures/build_home/design-source/assets/build.js | 1577 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C4-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C4-T03 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C4-T03 | src/lib/aiur/github/resource_store.ex | 2217 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C4-T03 | src/lib/aiur/github/transport.ex | 854 |  | MISMATCH (ledger says GH_ACCESS) |
| MP-E8-C4-T03 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C5-T01 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T01 | src/lib/aiur/workflow_store.ex | 542 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C5-T01 | src/test/aiur/core_test.exs | 4169 |  | MISMATCH (ledger says TEST_HARNESS) |
| MP-E8-C5-T02 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C5-T02 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T03 | src/lib/aiur/agent_control_cli.ex | 2898 |  | MISMATCH (ledger says CLI) |
| MP-E8-C5-T03 | src/lib/aiur/agent_environment.ex | 643 |  | MISMATCH (ledger says AGENT_CORE) |
| MP-E8-C5-T03 | src/lib/aiur/agent_runner/tool_executor.ex | 889 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C5-T03 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C5-T03 | src/lib/aiur/progress_retention.ex | 532 |  | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-E8-C5-T03 | src/test/aiur/agent_runner/tool_executor_test.exs | 1964 |  | MISMATCH (ledger says AGENT_TURN) |
| MP-E8-C5-T04 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 |  | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-E8-C5-T04 | src/test/aiur/aiur_agent_skill_test.exs | 876 |  | MISMATCH (ledger says SKILLS) |
| MP-E8-C6-T02 | src/lib/aiur/github/issues.ex | 1239 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C6-T02 | website/docs-app/apis/github.md | 820 |  | MISMATCH (ledger says DOCS) |
| MP-E8-C7-T02 | src/priv/build_orders/aiur-build-order.json | 729 |  | MISMATCH (ledger says BO_PUBLISH) |
| MP-E8-C8-T01 | src/test/fixtures/build_home/design-source/assets/build.js | 1577 |  | UNASSIGNED (>500, not in ledger — ask U0) |
| MP-E8-C8-T04 | src/lib/aiur/github/config.ex | 1089 |  | MISMATCH (ledger says GH_TRUST) |
| MP-E8-C8-T04 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-E8-C9-T03 | src/lib/aiur_web/live/dashboard_live.ex | 2280 |  | MISMATCH (ledger says WEB) |
| MP-N1-C1-T01 | packages/streamdeck/package-lock.json | 3028 | n/a (new package; no U8 ledger row) | MISMATCH (ledger says DECK_PKG) |
| MP-N1-C3-T04 | src/lib/aiur/orchestrator.ex | 956 | n/a (new package) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-N1-C4-T04 | src/priv/static/conversation-voice-controller.js | 539 | "U8 ledger owner of src/lib/aiur_web/components/layouts.ex (U6 scope src/lib/aiur_web/)" | MISMATCH (ledger says BROWSER) |
| MP-N1-C4-T05 | src/priv/static/conversation-voice-controller.js | 539 | n/a (new package) | MISMATCH (ledger says BROWSER) |
| MP-N1-C8-T01 | .github/workflows/release-npm.yml | 600 | n/a (script + docs) | MISMATCH (ledger says CI) |
| MP-N2-C10-T01 | — | — | "WEB (U8 ledger; look up the owner of http_server.ex and router.ex at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T02 | — | — | "n/a (new gateway modules); launcher lines in aiur-engine.sh are shared with U1/U9 — recheck at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T03 | — | — | "launcher dispatch in aiur-engine.sh (U1/U9 share the file; recheck lines at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C10-T04 | — | — | "WEB (endpoint.ex); look up at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C2-T01 | — | — | "aiur.ex child list (U8 ledger owner of src/lib/aiur.ex; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C2-T02 | — | — | "shutdown.ex (U8 ledger owner; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C3-T02 | — | — | "aiur-engine.sh and cli.ex (U1/U9 share the engine; look up owners at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C3-T04 | — | — | "init.ex (INI; look up at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C4-T01 | — | — | "cli.ex (U8 ledger owner; look up at the implementation SHA); new modules n/a" | NO-LONGER-OVERSIZED |
| MP-N2-C4-T02 | — | — | "aiur-engine.sh (shared with U1/U9; recheck line numbers at the implementation SHA)" | NO-LONGER-OVERSIZED |
| MP-N2-C5-T01 | — | — | "n/a (new modules under src/lib/aiur/machine/); launcher dispatch lines shared with U1/U9 — recheck at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C5-T02 | src/lib/aiur/alerts.ex | 762 | n/a (new gateway modules) | MISMATCH (ledger says EVENTS) |
| MP-N2-C6-T01 | — | — | "WEB — router.ex is in the U8 ledger (MP-N2-C6 named there); look up the owner at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C6-T02 | — | — | "WEB — financial_data_access.ex / proof.ex / router.ex; look up U8 owners at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C6-T03 | — | — | "WEB — router.ex (U8 ledger); look up at the implementation SHA" | NO-LONGER-OVERSIZED |
| MP-N2-C7-T01 | — | — | "n/a (new modules); engine dispatch lines shared with U1/U9" | NO-LONGER-OVERSIZED |
| MP-N2-C8-T02 | — | — | "WEB — router.ex and a new LiveView module (do not grow dashboard_live.ex, 2,903 lines, per U8)" | NO-LONGER-OVERSIZED |
| MP-N2-C9-T01 | — | — | "SITE/DOCS (U8 ledger)" | NO-LONGER-OVERSIZED |
| MP-N3-C1-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "n/a (new module; PRJ boundary owner per U8 ledger at implementation time)" | MISMATCH (ledger says CLI) |
| MP-N3-C1-T02 | src/lib/aiur/orchestrator.ex | 956 | "n/a (new provider module)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-N3-C1-T03 | src/test/aiur/decision_query_test.exs | 809 | "n/a (new provider module; DecisionQuery is read only)" | MISMATCH (ledger says DECISIONS) |
| MP-N3-C1-T04 | — | — | "n/a (new provider module)" | NO-LONGER-OVERSIZED |
| MP-N3-C1-T05 | — | — | "n/a (new provider module)" | NO-LONGER-OVERSIZED |
| MP-N3-C2-T01 | — | — | "n/a (new gateway module)" | NO-LONGER-OVERSIZED |
| MP-N3-C2-T02 | — | — | "n/a (new gateway module)" | NO-LONGER-OVERSIZED |
| MP-N4-C1-T01 | .github/workflows/release-npm.yml | 600 | n/a | MISMATCH (ledger says CI) |
| MP-N4-C2-T05 | website/docs-app/apis/github.md | 820 | n/a | MISMATCH (ledger says DOCS) |
| MP-N4-C2-T07 | website/docs-app/apis/github.md | 820 | n/a | MISMATCH (ledger says DOCS) |
| MP-N4-C3-T02 | src/lib/aiur/decision_store.ex | 4989 | n/a | MISMATCH (ledger says DECISIONS) |
| MP-N4-C3-T07 | src/lib/aiur/agent_control_cli.ex | 2898 | aiur-engine.sh / agent_control_cli.ex owners per U8 ledger | MISMATCH (ledger says CLI) |
| MP-N4-C3-T07 | src/test/aiur/agent_control_cli_test.exs | 3766 | aiur-engine.sh / agent_control_cli.ex owners per U8 ledger | MISMATCH (ledger says CLI) |
| MP-N5-C1-T03 | — | — | router.ex — web-shell owner per U8 ledger | NO-LONGER-OVERSIZED |
| MP-N6-C1-T01 | — | — | router.ex — web-shell owner per U8 ledger | NO-LONGER-OVERSIZED |
| MP-R1-C1-T01 | .github/workflows/ci.yml | 738 | n/a (new files; each < 500 lines) | MISMATCH (ledger says CI) |
| MP-R1-C10-T02 | website/docs-app/bun.lock | 593 | n/a   # ledger pinned at 465aca643; re-resolve at ticket start against the current U8 ledger (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says DOCS) |
| MP-R1-C10-T04 | — | — | CI (.github/workflows/ci.yml, 750 lines in the 465aca643 ledger, 770 at 45a290e3)   # re-resolve at ticket start against the current U8 ledger (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C10-T05 | — | — | DOCS (AGENTS.md, 639 lines at 45a290e3)   # re-resolve at ticket start against the current U8 ledger (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C2-T01 | — | — | "src/lib/aiur.ex: U8 package APP_BOOT (600 lines at release 0.0.7) — add at most 6 lines" | NO-LONGER-OVERSIZED |
| MP-R1-C3-T01 | — | — | "src/lib/aiur.ex: U8 APP_BOOT (600 lines) — add ≤ 4 lines" | NO-LONGER-OVERSIZED |
| MP-R1-C3-T03 | src/test/aiur/extensions_test.exs | 1925 | "src/lib/aiur_web/router.ex (361 lines) — add ≤ 3 lines" | MISMATCH (ledger says TEST_HARNESS) |
| MP-R1-C3-T04 | — | — | "packaging/npm/aiur-cli/libexec/aiur-engine.sh: U8 CLI (4,224 lines) and src/lib/aiur/agent_control_cli.ex: U8 CLI (3,362 lines) — add ≤ 25 and ≤ 5 lines; logic goes in a new file" | NO-LONGER-OVERSIZED |
| MP-R1-C4-T01 | — | — | "src/lib/aiur/config.ex: U8 CONFIG 'Configuration' (1,462 lines at release; split) — this ticket must shrink it" | NO-LONGER-OVERSIZED |
| MP-R1-C4-T02 | — | — | "src/lib/aiur/config.ex: U8 CONFIG (1,462 lines) — this ticket must shrink it" | NO-LONGER-OVERSIZED |
| MP-R1-C4-T03 | — | — | "src/lib/aiur/config.ex: U8 CONFIG (1,462 lines) — must shrink; src/lib/aiur/poll_cadence.ex 483 lines — must stay < 500" | NO-LONGER-OVERSIZED |
| MP-R1-C4-T04 | — | — | "src/lib/aiur/env.ex 492 lines — must not grow past 500" | NO-LONGER-OVERSIZED |
| MP-R1-C5-T02 | — | — | "src/lib/aiur/claude/remote_control.ex: U8 package CLAUDE 'Claude backend' (726 lines; split) — this ticket removes ~40 lines" | NO-LONGER-OVERSIZED |
| MP-R1-C5-T03 | — | — | "src/lib/aiur/alerts.ex: U8 EVENTS 'Alerts' (746 lines; split) — must not grow" | NO-LONGER-OVERSIZED |
| MP-R1-C5-T04 | — | — | "src/lib/aiur/run_telemetry/lifecycle.ex: U8 TELEMETRY 'Run telemetry' (557 lines; split) — must not grow" | NO-LONGER-OVERSIZED |
| MP-R1-C5-T05 | — | — | "per touched file: each change is a one-line call rename; no file grows" | NO-LONGER-OVERSIZED |
| MP-R1-C5-T06 | src/lib/aiur/orchestrator.ex | 956 | "per touched file: one-line call renames; orchestrator files over 500 lines keep their U8 owners and must not grow" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-R1-C6-T03 | — | — | APP_BOOT | NO-LONGER-OVERSIZED |
| MP-R1-C6-T04 | — | — | CLI | NO-LONGER-OVERSIZED |
| MP-R1-C7-T01 | src/test/aiur/extensions_test.exs | 1925 | WORKSPACE (src/lib/aiur/workspace/provisioner.ex, 743 lines; U8 ledger at 465aca643 — re-resolve at ticket start against the then-current ledger, RC-23 / MP-R1-C11-T02); other touched files are under 500 lines | MISMATCH (ledger says TEST_HARNESS) |
| MP-R1-C7-T01 | website/docs-app/apis/github.md | 820 | WORKSPACE (src/lib/aiur/workspace/provisioner.ex, 743 lines; U8 ledger at 465aca643 — re-resolve at ticket start against the then-current ledger, RC-23 / MP-R1-C11-T02); other touched files are under 500 lines | MISMATCH (ledger says DOCS) |
| MP-R1-C7-T02 | src/test/aiur/core_test.exs | 4169 | CONFIG (src/lib/aiur/config.ex, ledger row `src/lib/aiur/config.ex,1462,CONFIG,Configuration,split,medium` at 465aca643; 1,471 lines at 45a290e3); TEST_HARNESS owns core_test.exs and extensions_test.exs. Re-resolve at ticket start against the then-current U8 ledger (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says TEST_HARNESS) |
| MP-R1-C7-T03 | — | — | AGENT_CORE (agent_environment.ex 643, agent_process_log.ex 576); WORKSPACE (repo_base.ex 1,539, receives only delegates); other touched files < 500. Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C7-T04 | src/test/aiur/agent_environment_test.exs | 950 | AGENT_CORE (agent_environment.ex 643, agent_process_log.ex 576; test agent_environment_test.exs 947); GH_GUARD (agent_github_guard.ex 541 — read only, not edited). Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says AGENT_CORE) |
| MP-R1-C7-T04 | website/docs-app/apis/github.md | 820 | AGENT_CORE (agent_environment.ex 643, agent_process_log.ex 576; test agent_environment_test.exs 947); GH_GUARD (agent_github_guard.ex 541 — read only, not edited). Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says DOCS) |
| MP-R1-C7-T05 | — | — | WORKSPACE (repo_base.ex 1,539; workspace/ownership/guardian.ex 819; workspace/provisioner.ex 743; tests repo_base_test.exs, ownership_test.exs, workspace_and_config_test.exs). Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C7-T06 | src/priv/github_budget.py | 1112 | GH_ACCESS (quota.ex, transport.ex 860, read_cache/*); GH_TRUST (issues.ex 1,248 — not edited); other edited files < 500. Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says GH_GUARD) |
| MP-R1-C7-T06 | website/docs-app/apis/github.md | 820 | GH_ACCESS (quota.ex, transport.ex 860, read_cache/*); GH_TRUST (issues.ex 1,248 — not edited); other edited files < 500. Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | MISMATCH (ledger says DOCS) |
| MP-R1-C7-T07 | — | — | LIFECYCLE_DISPATCH (orchestrator/dispatcher.ex 2,670 in ledger, 2,673 at base; dispatcher_test.exs 3,197). Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C7-T08 | — | — | LIFECYCLE_DISPATCH (orchestrator/dispatcher.ex 2,673 at base; dispatcher_test.exs 3,197); GH_ACCESS (github/ci_readiness.ex 1,149 — gains only @behaviour/@impl lines). Pinned to U8 ledger 465aca643; re-resolve at ticket start (RC-23, MP-R1-C11-T02) | NO-LONGER-OVERSIZED |
| MP-R1-C8-T01 | src/test/aiur/agent_runner/queue_drain_test.exs | 1003 | DECISIONS (U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02; this ticket adds no lines to decision_store.ex) | MISMATCH (ledger says AGENT_TURN) |
| MP-R1-C8-T01 | src/test/aiur/decision_store_test.exs | 4847 | DECISIONS (U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02; this ticket adds no lines to decision_store.ex) | MISMATCH (ledger says DECISIONS) |
| MP-R1-C8-T01 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | DECISIONS (U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02; this ticket adds no lines to decision_store.ex) | MISMATCH (ledger says WEB) |
| MP-R1-C8-T02 | — | — | DECISIONS (decision_store.ex) and LIFECYCLE_DISPATCH (dispatcher.ex, operator_messages.ex) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02 | NO-LONGER-OVERSIZED |
| MP-R1-C8-T03 | src/test/aiur/current_run_projections_test.exs | 1374 | WEB (units_row_test.exs, 597 lines) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02. No moved production file is over 500 lines. | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-R1-C8-T04 | src/test/aiur/current_run_projections_test.exs | 1374 | LIFECYCLE_STATUS (open_ticket_source.ex 509, progress_retention.ex 532, ticket_activity/projection.ex 605 — reassigned only in the manifest, not edited) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02 | MISMATCH (ledger says LIFECYCLE_STATUS) |
| MP-R1-C8-T06 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | OPENCODE (live_conversation.ex 691, not edited), DECK_WEB (streamdeck_logs.ex 637; this ticket changes ≤4 lines) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02 | MISMATCH (ledger says WEB) |
| MP-R1-C8-T07 | website/docs-app/apis/github.md | 820 | GH_ACCESS (github/client.ex — confirm row) and BO_RUNTIME — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02 | MISMATCH (ledger says DOCS) |
| MP-R1-C8-T08 | — | — | BO_RUNTIME (graph_projection.ex 1,825, build_order_presenter.ex 1,046 — not edited) and APP_BOOT (src/lib/aiur.ex child order) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02 | NO-LONGER-OVERSIZED |
| MP-R1-C8-T09 | — | — | LIFECYCLE_DISPATCH (dispatch_policy.ex, issue_sync.ex — hooks preserved, not edited) — U8 ledger at 465aca643; re-resolve at ticket start per RC-23 / MP-R1-C11-T02. build_queue/ files are new in MP-E1 and must each be ≤500 lines. | NO-LONGER-OVERSIZED |
| MP-R1-C9-T01 | website/docs-app/apis/github.md | 820 | LIFECYCLE_DISPATCH (orchestrator/state.ex, orchestrator/dispatcher.ex, orchestrator/comment_polling.ex); EVENTS (tests under src/test/aiur/events/) | MISMATCH (ledger says DOCS) |
| MP-R1-C9-T02 | — | — | LIFECYCLE_DISPATCH (orchestrator/comment_polling.ex, orchestrator/comment_polling/target_selection.ex, orchestrator/state.ex) | NO-LONGER-OVERSIZED |
| MP-R1-C9-T03 | website/docs-app/apis/github.md | 820 | LIFECYCLE_DISPATCH (orchestrator.ex, orchestrator/state.ex, orchestrator/lifecycle.ex, orchestrator/comment_polling*); EVENTS (events/github_webhook.ex tests) | MISMATCH (ledger says DOCS) |
| MP-R1-C9-T04 | — | — | LIFECYCLE_DISPATCH (orchestrator/state.ex, orchestrator/dispatcher.ex); command_scan.ex (417 lines) is not in the U8 ledger -> n/a for that file | NO-LONGER-OVERSIZED |
| MP-R1-C9-T06 | — | — | LIFECYCLE_STATUS (src/test/aiur/orchestrator/rework_requeue_test.exs, 522 lines); rework_requeue.ex (459) not in the ledger | NO-LONGER-OVERSIZED |
| MP-R1-C9-T07 | src/lib/aiur/orchestrator/state.ex | 1025 | LIFECYCLE_DISPATCH (orchestrator/state.ex, 1,033 lines at base) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
