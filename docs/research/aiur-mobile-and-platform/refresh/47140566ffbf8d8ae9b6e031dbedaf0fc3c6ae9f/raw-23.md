| MP-R1-C9-T08 | src/lib/aiur/orchestrator.ex | 956 | LIFECYCLE_DISPATCH (orchestrator.ex, issue_sync.ex, comment_wake.ex, comment_polling.ex, dispatcher.ex, state.ex); LIFECYCLE_STATUS (reconciler.ex, pause_resume.ex) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-R1-C9-T09 | src/lib/aiur/orchestrator.ex | 956 | LIFECYCLE_STATUS (reconciler.ex); LIFECYCLE_DISPATCH (orchestrator.ex, comment_wake.ex, operator_messages.ex, push_routing.ex); re-resolve at start | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-R1-C9-T10 | src/lib/aiur/agent_control_cli.ex | 2898 | CLI (src/lib/aiur/agent_control_cli.ex 3,362 lines in the ledger; 3,482 at 45a290e3; src/test/aiur/agent_control_cli_test.exs) | MISMATCH (ledger says CLI) |
| MP-R1-C9-T11 | src/lib/aiur/agent_control_cli.ex | 2898 | CLI (agent_control_cli.ex, agent_control_cli_test.exs) | MISMATCH (ledger says CLI) |
| MP-R1-C9-T11 | src/test/aiur/agent_control_cli_test.exs | 3766 | CLI (agent_control_cli.ex, agent_control_cli_test.exs) | MISMATCH (ledger says CLI) |
| MP-R1-C9-T12 | src/lib/aiur/agent_control_cli.ex | 2898 | CLI (agent_control_cli.ex, agent_control_cli_test.exs) | MISMATCH (ledger says CLI) |
| MP-R1-C9-T13 | src/lib/aiur/agent_control_cli.ex | 2898 | CLI (agent_control_cli.ex, agent_control_cli_test.exs) | MISMATCH (ledger says CLI) |
| MP-R1-C9-T14 | — | — | CLI (agent_control_cli.ex, agent_control_cli_test.exs); LIFECYCLE_STATUS (orchestrator/status_report.ex, status_report_test.exs) | NO-LONGER-OVERSIZED |
| MP-R2-C1-T02 | src/test/aiur/events/subscription_store_test.exs | 611 | n/a (test-only) | MISMATCH (ledger says EVENTS) |
| MP-R2-C2-T01 | src/lib/aiur/events/subscription_store.ex | 745 | EVENTS (subscription_store.ex, 748 lines at base; re-check at start per RC-23) | MISMATCH (ledger says EVENTS) |
| MP-R2-C2-T02 | website/docs-app/apis/github.md | 820 | EVENTS (sanitizer.ex 393 lines, under 500; re-check at start per RC-23) | MISMATCH (ledger says DOCS) |
| MP-R2-C2-T03 | src/lib/aiur/events/publisher.ex | 539 | EVENTS (publisher.ex 539, subscription_store.ex 748); LIFECYCLE_STATUS (issue_log.ex 1049, not edited). Re-check at start per RC-23. | MISMATCH (ledger says EVENTS) |
| MP-R2-C2-T04 | src/lib/aiur/events/publisher.ex | 539 | n/a (event_source.ex 59 lines) | MISMATCH (ledger says EVENTS) |
| MP-R2-C2-T05 | — | — | EVENTS (publisher.ex 539, subscription_store.ex 748); re-check at start per RC-23 | NO-LONGER-OVERSIZED |
| MP-R2-C2-T06 | website/docs-app/apis/github.md | 820 | EVENTS (publisher.ex 539 lines; must shrink); re-check at start per RC-23 | MISMATCH (ledger says DOCS) |
| MP-R2-C2-T08 | — | — | EVENTS (github_comments_poller.ex, github_firehose.ex, github_webhook.ex if > 500 at start); re-check per RC-23 | NO-LONGER-OVERSIZED |
| MP-R2-C2-T09 | — | — | ORC owners for ci_lifecycle.ex, pause_resume.ex, command_scan.ex (look up at start per RC-23); no file may grow | NO-LONGER-OVERSIZED |
| MP-R2-C2-T10 | src/lib/aiur/agent_runner/tool_executor.ex | 889 | DECISIONS (decision_store.ex 4826), EVENTS (executor_events.ex 525, alerts.ex 746); others < 500 at base. Re-check per RC-23; no file may grow. | MISMATCH (ledger says AGENT_TURN) |
| MP-R2-C2-T10 | src/lib/aiur/alerts.ex | 762 | DECISIONS (decision_store.ex 4826), EVENTS (executor_events.ex 525, alerts.ex 746); others < 500 at base. Re-check per RC-23; no file may grow. | MISMATCH (ledger says EVENTS) |
| MP-R2-C2-T10 | src/lib/aiur/decision_store.ex | 4989 | DECISIONS (decision_store.ex 4826), EVENTS (executor_events.ex 525, alerts.ex 746); others < 500 at base. Re-check per RC-23; no file may grow. | MISMATCH (ledger says DECISIONS) |
| MP-R2-C2-T10 | src/lib/aiur/executor_events.ex | 559 | DECISIONS (decision_store.ex 4826), EVENTS (executor_events.ex 525, alerts.ex 746); others < 500 at base. Re-check per RC-23; no file may grow. | MISMATCH (ledger says EVENTS) |
| MP-R2-C3-T01 | src/lib/aiur/executor_events.ex | 559 | EVENTS (executor_events.ex 525 lines; must not grow); re-check at start per RC-23 | MISMATCH (ledger says EVENTS) |
| MP-R2-C3-T02 | src/lib/aiur/events/publisher.ex | 539 | EVENTS (executor_events.ex 525 lines; must shrink); re-check at start per RC-23 | MISMATCH (ledger says EVENTS) |
| MP-R2-C3-T02 | src/lib/aiur/executor_events.ex | 559 | EVENTS (executor_events.ex 525 lines; must shrink); re-check at start per RC-23 | MISMATCH (ledger says EVENTS) |
| MP-R2-C4-T01 | src/lib/aiur/orchestrator/comment_wake.ex | 1767 | n/a (manifest edit; components.json is formatted by check-components.py --format, MP-R1-C1-T01) | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| MP-R2-C4-T03 | .github/workflows/ci.yml | 738 | n/a | MISMATCH (ledger says CI) |
| MP-R2-C4-T03 | src/lib/aiur/agent_control_cli.ex | 2898 | n/a | MISMATCH (ledger says CLI) |
| MP-R2-C5-T01 | src/lib/aiur/alerts.ex | 762 | n/a (new files; each ≤ 200 lines preferred, ≤ 500 hard) | MISMATCH (ledger says EVENTS) |
| MP-R2-C5-T02 | src/lib/aiur/events/publisher.ex | 539 | n/a (new file, ≤ 200 lines) | MISMATCH (ledger says EVENTS) |
| MP-R2-C5-T02 | src/lib/aiur/executor_events.ex | 559 | n/a (new file, ≤ 200 lines) | MISMATCH (ledger says EVENTS) |
| MP-R2-C6-T01 | .github/workflows/ci.yml | 738 | n/a (config/schema/events.ex 25 lines; config.ex owner looked up at start per RC-23 — must not grow by more than the 3 accessors) | MISMATCH (ledger says CI) |
| MP-R2-C6-T02 | src/lib/aiur/executor_events.ex | 559 | APP_BOOT (aiur.ex 610 at base; this ticket adds ≤ 3 lines — offset or justify per the U0 size gate at start, RC-23); new files ≤ 300 lines each | MISMATCH (ledger says EVENTS) |
| MP-R2-C7-T01 | — | — | router.ex (WEB; re-check at start per RC-23); new controller < 200 lines | NO-LONGER-OVERSIZED |
| MP-R2-C7-T04 | src/lib/aiur/agent_control_cli.ex | 2898 | CLI (aiur-engine.sh 4224 and agent_control_cli.ex 3362 in the U8 ledger, both shrink-only); re-check per RC-23 | MISMATCH (ledger says CLI) |
| MP-R3-C2-T01 | src/priv/static/conversation-voice-controller.js | 539 | n/a (optional-optimizations.md is 174 lines) | MISMATCH (ledger says BROWSER) |
| MP-R4-C1-T01 | website/docs-app/apis/github.md | 820 | DOCS (website/docs-app/apis/github.md, 760 lines at base) | MISMATCH (ledger says DOCS) |
| MP-R5-C1-T01 | — | — | "DECK_WEB (streamdeck_channel.ex 609 lines): edit is a net-zero rename" | NO-LONGER-OVERSIZED |
| MP-R5-C1-T03 | — | — | "DECK_WEB (streamdeck_channel.ex 609, streamdeck_projection.ex 540): net-neutral or smaller" | NO-LONGER-OVERSIZED |
| MP-R5-C2-T01 | src/lib/aiur_web/live/dashboard_live.ex | 2280 | "WEB (dashboard_live.ex 2,903 lines): edit must be net-neutral" | MISMATCH (ledger says WEB) |
| MP-R5-C2-T02 | .github/workflows/ci.yml | 738 | n/a | MISMATCH (ledger says CI) |
| MP-R5-C4-T01 | src/priv/static/conversation-voice-controller.js | 539 | n/a (apis/elevenlabs.md is 57 lines) | MISMATCH (ledger says BROWSER) |
| MP-R5-C4-T02 | .github/workflows/ci.yml | 738 | n/a (deletion) | MISMATCH (ledger says CI) |
| MP-R6-C1-T01 | — | — | "DECK_WEB (streamdeck_logs.ex 637 lines): this ticket shrinks it" | NO-LONGER-OVERSIZED |
| MP-R6-C2-T01 | .github/workflows/ci.yml | 738 | "DECK_WEB / DECK_PKG: only small edits, no file over 500 lines grows" | MISMATCH (ledger says CI) |
| MP-R6-C2-T01 | src/priv/static/conversation-voice-controller.js | 539 | "DECK_WEB / DECK_PKG: only small edits, no file over 500 lines grows" | MISMATCH (ledger says BROWSER) |
| MP-R7-C1-T04 | .github/workflows/ci.yml | 738 | n/a (test tags and a mix alias only) | MISMATCH (ledger says CI) |
| MP-R7-C1-T04 | src/test/aiur/agent_runner/queue_drain_test.exs | 1003 | n/a (test tags and a mix alias only) | MISMATCH (ledger says AGENT_TURN) |
| MP-R7-C2-T01 | — | — | "Aiur core / coding agent (registry data only; coding_agent.ex not edited)" | NO-LONGER-OVERSIZED |
| MP-R7-C2-T02 | — | — | "Aiur core / coding agent (backend.ex, 148 lines)" | NO-LONGER-OVERSIZED |
| MP-R7-C2-T03 | — | — | "Ticket lifecycle and dispatch (operator_messages/capabilities.ex, 125 lines)" | NO-LONGER-OVERSIZED |
| MP-R7-C3-T01 | src/test/aiur/agent_runner/tool_executor_test.exs | 1964 | n/a (no moved file exceeds 500 lines; largest is errors.ex at 430) | MISMATCH (ledger says AGENT_TURN) |
| MP-R7-C3-T03 | src/lib/aiur/agent_runner/session_lifecycle.ex | 1290 | AGENT_TURN (agent_runner/session_lifecycle.ex, 1,124 lines; split is U8's, not this ticket's) | MISMATCH (ledger says AGENT_TURN) |
| MP-R7-C3-T03 | src/test/aiur/agent_runner/session_lifecycle_test.exs | 1110 | AGENT_TURN (agent_runner/session_lifecycle.ex, 1,124 lines; split is U8's, not this ticket's) | MISMATCH (ledger says AGENT_TURN) |
| MP-R7-C3-T06 | — | — | "src/lib/aiur/config.ex: U8 CONFIG owner (look up at the implementation SHA, RC-23)" | NO-LONGER-OVERSIZED |
| MP-R7-C4-T03 | — | — | AGENT_CORE (src/lib/aiur/coding_agent.ex, 1,179 lines) | NO-LONGER-OVERSIZED |
| MP-R7-C4-T04 | — | — | CLAUDE (remote_control.ex 726, telemetry.ex 666, coding_agent.ex 534); CODEX (event_humanizer.ex 510) | NO-LONGER-OVERSIZED |
| MP-R7-C4-T05 | .github/workflows/ci.yml | 738 | n/a | MISMATCH (ledger says CI) |
| MP-R7-C4-T05 | .github/workflows/release-npm.yml | 600 | n/a | MISMATCH (ledger says CI) |
| U0-T02 | packages/aiur-style/package-lock.json | 2884 | n/a | UNASSIGNED (>500, not in ledger — ask U0) |
| U0-T02 | src/lib/aiur/accounts.ex | 724 | n/a | UNASSIGNED (>500, not in ledger — ask U0) |
| U0-T03 | .github/workflows/ci.yml | 738 | "CI (.github/workflows/ci.yml, 750+ lines; add <= 4 lines)" | MISMATCH (ledger says CI) |
| U1-T01 | — | — | "test files < 500 lines; no owner needed" | NO-LONGER-OVERSIZED |
| U1-T02 | — | — | "CLI (aiur-engine.sh 4,352 lines; no production growth expected; src/test/aiur_engine_stop_pidfile_test.exs 105 lines)" | NO-LONGER-OVERSIZED |
| U2-T01 | — | — | "LIFECYCLE_DISPATCH / LIFECYCLE_STATUS (call sites in issue_sync.ex 2,301, dispatcher.ex 2,686, pause_resume.ex 2,490, retry_engine.ex 1,557); CLI (agent_control_cli.ex). Each edit swaps a call or an injected default; growth of 0-2 lines per file, offset where the file is over 500." | NO-LONGER-OVERSIZED |
| U2-T02 | — | — | "LIFECYCLE_DISPATCH (issue_sync.ex 2,301; net change must be <= 0: the wrapper moves out)" | NO-LONGER-OVERSIZED |
| U2-T03 | — | — | "LIFECYCLE_DISPATCH (rate_limit_fallback.ex 763 at HEAD; net growth <= 0 - shrink by removing duplicated entry building); state.ex 1,037 (one new field, offset elsewhere)" | NO-LONGER-OVERSIZED |
| U2-T04 | — | — | "LIFECYCLE_STATUS (status_report.ex 1,489; growth must be offset - move reason building into waiting_reason.ex, < 500)" | NO-LONGER-OVERSIZED |
| U2-T05 | — | — | "WORKSPACE (guardian.ex 819; ownership_test.exs 1,243 - no net growth; add tests in a new file if needed)" | NO-LONGER-OVERSIZED |
| U3-T01 | src/lib/aiur/events/subscription_store.ex | 745 | "EVENTS (subscription_store.ex 748; net growth <= 0 - the inline drain replaces the self-send loop)" | MISMATCH (ledger says EVENTS) |
| U3-T02 | — | — | "under 500 (claims.ex 485 - keep under 500: net growth <= 15 lines)" | NO-LONGER-OVERSIZED |
| U3-T03 | src/lib/aiur/executor_wake_inbox.ex | 618 | "EVENTS (executor_wake_inbox.ex 619; net growth <= 0 - fold duplicated error paths)" | MISMATCH (ledger says EVENTS) |
| U4-T01 | — | — | "AGENT_TURN (queue_drain.ex 824, turn_loop.ex 591; net growth < 0 - two copies become one); LIFECYCLE_STATUS (pause_resume.ex, call-site only)" | NO-LONGER-OVERSIZED |
| U4-T02 | — | — | "AGENT_TURN (turn_loop.ex 591; net growth <= 0)" | NO-LONGER-OVERSIZED |
| U4-T03 | — | — | "CLAUDE (claude/coding_agent.ex 534; net growth <= 0 - reuse the Codex helper); startup_failure.ex < 200" | NO-LONGER-OVERSIZED |
| U5-T01 | website/docs-app/apis/github.md | 820 | "GH_ACCESS (transport.ex 860; net growth <= 5); comments.ex 233, pull_requests.ex small" | MISMATCH (ledger says DOCS) |
| U5-T02 | website/docs-app/apis/github.md | 820 | "GH_TRUST (codeowners.ex 657 must shrink - delete its private fetchers and second grammar; code_owners.ex 487 must stay < 500)" | MISMATCH (ledger says DOCS) |
| U5-T03 | — | — | "GH_ACCESS (resource_store.ex 2,261 - new function must be offset by removing the unconditional put; net growth <= 0); GH_TRUST (issues.ex 1,263, call-site only)" | NO-LONGER-OVERSIZED |
| U5-T04 | — | — | "GH_ACCESS (transport.ex 860, quota.ex 1,380 - no net growth: return shape only; review_threads/reply.ex < 500); DOCS (apis/github.md 779 - replace in place only)" | NO-LONGER-OVERSIZED |
| U6-T01 | — | — | "DECISIONS (decision_store.ex 4,826 - minimal edits, follow-up retry in a small new function; decision_log.ex stays < 500)" | NO-LONGER-OVERSIZED |
| U6-T02 | — | — | "DECISIONS (decision_store.ex 4,826 - minimal edits; decision_projection.ex < 500)" | NO-LONGER-OVERSIZED |
| U6-T03 | — | — | "under 500 (usage_aggregate/store.ex 335)" | NO-LONGER-OVERSIZED |
| U6-T04 | — | — | "LIFECYCLE_STATUS (status_report.ex 1,489), CLI (agent_control_cli.ex 3,362), WEB (presenter.ex 595) - no net growth per file; shared field list lives in status_report.ex" | NO-LONGER-OVERSIZED |
| U6-T05 | — | — | "WEB (analytics/presenter.ex 1,101 - no net growth); control_center_cache.ex < 500" | NO-LONGER-OVERSIZED |
| U7-T02 | — | — | "deletes linear/client.ex 599; touches config.ex and tracker.ex call sites only" | NO-LONGER-OVERSIZED |
| U8-P00-T01 | .github/workflows/ci.yml | 738 | "DECK_PKG, DOCS, SITE (lockfile rows) (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says CI) |
| U8-P00-T01 | packages/aiur-style/package-lock.json | 2884 | "DECK_PKG, DOCS, SITE (lockfile rows) (ledger 465aca643; recount 58854d4c8)" | UNASSIGNED (>500, not in ledger — ask U0) |
| U8-P00-T01 | packages/streamdeck/package-lock.json | 3028 | "DECK_PKG, DOCS, SITE (lockfile rows) (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECK_PKG) |
| U8-P00-T01 | website/docs-app/bun.lock | 593 | "DECK_PKG, DOCS, SITE (lockfile rows) (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P00-T01 | website/package-lock.json | 1657 | "DECK_PKG, DOCS, SITE (lockfile rows) (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says SITE) |
| U8-P00-T02 | — | — | "all (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P01-T01 | — | — | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P01-T02 | src/lib/aiur/accounts.ex | 724 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | UNASSIGNED (>500, not in ledger — ask U0) |
| U8-P01-T02 | src/lib/aiur/agent_environment.ex | 643 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P01-T02 | src/lib/aiur/agent_process_log.ex | 576 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P01-T02 | src/lib/aiur/model_availability.ex | 571 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | UNASSIGNED (>500, not in ledger — ask U0) |
| U8-P01-T02 | src/lib/aiur/model_discovery.ex | 827 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P01-T02 | src/test/aiur/accounts_test.exs | 661 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | UNASSIGNED (>500, not in ledger — ask U0) |
| U8-P01-T02 | src/test/aiur/agent_environment_test.exs | 950 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P01-T02 | src/test/aiur/agent_log_test.exs | 753 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P01-T02 | src/test/aiur/model_discovery_test.exs | 564 | "AGENT_CORE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_CORE) |
| U8-P02-T01 | src/lib/aiur/agent_runner.ex | 749 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/lib/aiur/agent_runner/message_handler.ex | 671 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/lib/aiur/agent_runner/tool_executor.ex | 889 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/lib/aiur/agent_runner/turn_loop.ex | 634 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/test/aiur/agent_runner/message_handler_test.exs | 539 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/test/aiur/agent_runner/tool_executor_test.exs | 1964 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T01 | src/test/aiur/agent_runner_test.exs | 804 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/lib/aiur/agent_queue_store.ex | 597 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/lib/aiur/agent_runner/queue_drain.ex | 802 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/lib/aiur/agent_runner/session_lifecycle.ex | 1290 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/agent_queue_test.exs | 538 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/agent_runner/provider_lifecycle_test.exs | 511 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/agent_runner/queue_drain_test.exs | 1003 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/agent_runner/session_lifecycle_test.exs | 1110 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/app_server/adapter_test.exs | 574 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P02-T02 | src/test/aiur/app_server_test.exs | 1401 | "AGENT_TURN (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says AGENT_TURN) |
| U8-P03-T01 | src/test/fixtures/analytics/builds/test-build/build-summary.json | 1227 | "ANALYTICS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says ANALYTICS) |
| U8-P03-T01 | src/test/fixtures/analytics/runs/boot-a/run-summary.json | 1042 | "ANALYTICS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says ANALYTICS) |
| U8-P04-T01 | — | — | "APP_BOOT (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P05-T01 | — | — | "BO_DESIGN (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P06-T01 | — | — | "BO_PUBLISH (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P06-T02 | src/priv/build_orders/aiur-build-order.json | 729 | "BO_PUBLISH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says BO_PUBLISH) |
| U8-P06-T02 | src/priv/build_orders/croptracker-demo.json | 1611 | "BO_PUBLISH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says BO_PUBLISH) |
| U8-P07-T01 | — | — | "BO_RUNTIME (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P07-T02 | — | — | "BO_RUNTIME (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P07-T03 | — | — | "BO_RUNTIME (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P08-T01 | — | — | "BROWSER (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P08-T02 | — | — | "BROWSER (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P09-T01 | — | — | "BUILD_GATE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P10-T01 | — | — | "CE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P11-T01 | .github/workflows/ci.yml | 738 | "CI (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says CI) |
| U8-P11-T01 | .github/workflows/release-npm.yml | 600 | "CI (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says CI) |
| U8-P12-T01 | — | — | "CLAUDE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P12-T02 | — | — | "CLAUDE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P13-T01 | — | — | "CLI (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P13-T02 | — | — | "CLI (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P14-T01 | src/lib/aiur/agent_control_cli.ex | 2898 | "CODEX (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says CLI) |
| U8-P15-T01 | — | — | "CONFIG (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P15-T02 | — | — | "CONFIG (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P16-T01 | src/lib/aiur/decision_store.ex | 4989 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T01 | src/test/aiur/decision_store_test.exs | 4847 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/lib/aiur/decision_attention.ex | 542 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | UNASSIGNED (>500, not in ledger — ask U0) |
| U8-P16-T02 | src/lib/aiur/decision_event.ex | 1056 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/lib/aiur/decision_history.ex | 540 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/lib/aiur/decision_projection.ex | 1039 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_api_test.exs | 964 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_attention_test.exs | 778 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_projection_test.exs | 1036 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_query_test.exs | 809 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_revision_store_test.exs | 766 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P16-T02 | src/test/aiur/decision_withdrawal_test.exs | 594 | "DECISIONS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DECISIONS) |
| U8-P17-T01 | — | — | "DECK_DESIGN (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P18-T01 | — | — | "DECK_PKG (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P19-T01 | — | — | "DECK_WEB (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P19-T02 | — | — | "DECK_WEB (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P20-T01 | — | — | "DOCS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P20-T02 | website/docs-app/apis/github.md | 820 | "DOCS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P21-T01 | website/docs-app/apis/github.md | 820 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P21-T02 | — | — | "EVENTS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P21-T03 | src/lib/aiur/alerts.ex | 762 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/lib/aiur/events/publisher.ex | 539 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/lib/aiur/events/subscription_store.ex | 745 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/lib/aiur/executor_events.ex | 559 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/lib/aiur/executor_wake_inbox.ex | 618 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/test/aiur/alerts_test.exs | 1382 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P21-T03 | src/test/aiur/events/subscription_store_test.exs | 611 | "EVENTS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says EVENTS) |
| U8-P22-T01 | src/lib/aiur/github/resource_store.ex | 2217 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T01 | src/test/aiur/github/resource_fetch_test.exs | 563 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T01 | src/test/aiur/github/resource_store_test.exs | 1950 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T01 | src/test/aiur/github/view_state_sweep_test.exs | 603 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T01 | website/docs-app/apis/github.md | 820 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P22-T02 | src/lib/aiur/github/budget.ex | 928 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T02 | src/lib/aiur/github/quota.ex | 1380 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T02 | src/priv/github_budget.py | 1112 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_GUARD) |
| U8-P22-T02 | src/test/aiur/github/budget_test.exs | 1252 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T02 | src/test/aiur/github/quota_test.exs | 1002 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T02 | website/docs-app/apis/github.md | 820 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P22-T03 | — | — | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P22-T04 | src/lib/aiur/github/read_cache.ex | 555 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | src/lib/aiur/github/read_cache/policy.ex | 546 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | src/lib/aiur/github/transport.ex | 854 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | src/test/aiur/github/mutation_write_through_test.exs | 619 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | src/test/aiur/github/read_cache_test.exs | 1423 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | src/test/aiur/regression/github_ingestion_test.exs | 790 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_ACCESS) |
| U8-P22-T04 | website/docs-app/apis/github.md | 820 | "GH_ACCESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P23-T01 | website/docs-app/apis/github.md | 820 | "GH_GUARD (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P23-T02 | src/priv/github_budget.py | 1112 | "GH_GUARD (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_GUARD) |
| U8-P24-T01 | src/lib/aiur/github/auth_preflight.ex | 549 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/lib/aiur/github/config.ex | 1089 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/lib/aiur/github/dispatch_authorization.ex | 768 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/lib/aiur/github/issues.ex | 1239 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/test/aiur/github/auth_preflight_test.exs | 687 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/test/aiur/github/config_test.exs | 918 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/test/aiur/github/dispatch_authorization_test.exs | 1066 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/test/aiur/github/issue_state_test.exs | 611 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | src/test/aiur/github/issues_test.exs | 1506 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says GH_TRUST) |
| U8-P24-T01 | website/docs-app/apis/github.md | 820 | "GH_TRUST (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says DOCS) |
| U8-P25-T01 | — | — | "HIST_CE + HIST_PRODUCT (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P25-T02 | — | — | "HIST_CE (provisional, new row) (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P27-T01 | src/browser/layout/aiur-layout-worker.js | 507 | "LAYOUT (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LAYOUT) |
| U8-P27-T01 | src/browser/tests/layout-worker.browser.spec.mjs | 1185 | "LAYOUT (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LAYOUT) |
| U8-P27-T01 | src/priv/static/vendor/elk/0.11.1/aiur-layout-worker.js | 507 | "LAYOUT (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LAYOUT) |
| U8-P27-T01 | src/priv/static/vendor/elk/0.11.1/elk-worker.min.js | 6312 | "LAYOUT (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LAYOUT) |
| U8-P28-T01 | — | — | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P28-T02 | src/lib/aiur/orchestrator/issue_sync.ex | 2550 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T02 | src/test/aiur/orchestrator/issue_sync_test.exs | 3223 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T03 | src/lib/aiur/orchestrator/rate_limit_fallback.ex | 690 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T03 | src/lib/aiur/orchestrator/retry_engine.ex | 1651 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T03 | src/test/aiur/orchestrator/lifetime_dispatch_budget_test.exs | 775 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T03 | src/test/aiur/orchestrator/rate_limit_fallback_test.exs | 923 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T03 | src/test/aiur/orchestrator/retry_engine_test.exs | 2106 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T04 | src/lib/aiur/orchestrator/comment_polling.ex | 1068 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T04 | src/lib/aiur/orchestrator/comment_polling/target_selection.ex | 527 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T04 | src/lib/aiur/orchestrator/comment_wake.ex | 1767 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T04 | src/test/aiur/orchestrator/comment_wake_test.exs | 1554 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T05 | — | — | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P28-T06 | src/lib/aiur/orchestrator.ex | 956 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T06 | src/lib/aiur/orchestrator/state.ex | 1025 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T06 | src/test/aiur/regression/orchestrator_blocking_http_test.exs | 1230 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P28-T06 | src/test/aiur/regression/orchestrator_lifecycle_test.exs | 764 | "LIFECYCLE_DISPATCH (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_DISPATCH) |
| U8-P29-T01 | — | — | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P29-T02 | — | — | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P29-T03 | — | — | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P29-T04 | src/lib/aiur/orchestrator/control_lifecycle.ex | 950 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T04 | src/lib/aiur/orchestrator/reconciler.ex | 853 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T04 | src/test/aiur/orchestrator/merged_ticket_reconciler_test.exs | 532 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T04 | src/test/aiur/orchestrator/orphaned_workers_test.exs | 516 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T04 | src/test/aiur/orchestrator/reconciler_test.exs | 1057 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/lib/aiur/orchestrator/snapshot_store.ex | 553 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/lib/aiur/progress_retention.ex | 532 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/lib/aiur/workflow_store.ex | 542 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/test/aiur/coordination_tasks_test.exs | 510 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/test/aiur/current_run_membership_store_test.exs | 785 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T05 | src/test/aiur/current_run_projections_test.exs | 1374 | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LIFECYCLE_STATUS) |
| U8-P29-T06 | — | — | "LIFECYCLE_STATUS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P30-T01 | src/lib/aiur/linear/client.ex | 599 | "LINEAR (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says LINEAR) |
| U8-P31-T01 | — | — | "OPENCODE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P31-T02 | — | — | "OPENCODE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P32-T01 | — | — | "SITE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P33-T01 | .github/workflows/ci.yml | 738 | "SKILLS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says CI) |
| U8-P33-T01 | src/test/aiur/aiur_agent_skill_test.exs | 876 | "SKILLS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says SKILLS) |
| U8-P34-T01 | — | — | "TELEMETRY (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P34-T02 | — | — | "TELEMETRY (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P35-T01 | — | — | "TEST_HARNESS (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P35-T02 | src/test/aiur/core_test.exs | 4169 | "TEST_HARNESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says TEST_HARNESS) |
| U8-P35-T02 | src/test/aiur/extensions_test.exs | 1925 | "TEST_HARNESS (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says TEST_HARNESS) |
| U8-P36-T01 | src/lib/aiur_web/live/dashboard_live.ex | 2280 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P36-T01 | src/test/aiur_web/live/dashboard_live_test.exs | 6678 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P36-T02 | — | — | "WEB (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P36-T03 | src/lib/aiur_web/live/analytics_live.ex | 710 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P36-T03 | src/lib/aiur_web/operator_control_center/analytics/charts.ex | 654 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P36-T03 | src/lib/aiur_web/operator_control_center/analytics/presenter.ex | 1035 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P36-T03 | src/test/aiur_web/live/analytics_live_test.exs | 1143 | "WEB (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WEB) |
| U8-P37-T01 | — | — | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P37-T02 | — | — | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | NO-LONGER-OVERSIZED |
| U8-P37-T03 | src/lib/aiur/workspace/ownership/guardian.ex | 885 | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WORKSPACE) |
| U8-P37-T03 | src/lib/aiur/workspace/provisioner.ex | 774 | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WORKSPACE) |
| U8-P37-T03 | src/test/aiur/regression/workspace_lifecycle_test.exs | 846 | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WORKSPACE) |
| U8-P37-T03 | src/test/aiur/workspace/ownership_test.exs | 1488 | "WORKSPACE (ledger 465aca643; recount 58854d4c8)" | MISMATCH (ledger says WORKSPACE) |
| U9-T03 | — | — | "CI (.github/workflows/ci.yml 750+; add <= 6 lines)" | NO-LONGER-OVERSIZED |

## Contract versions (metadata only)

| Contract | Status | Base main SHA | Date |
| --- | --- | --- | --- |
| identity-and-capabilities | reconciled (Phase D fix pass; applies RC-01, RC-02, RC-04, RC-11, RC-12, RC-36, RC-37, RC-39, RC-40; X-02, X-21, X-35) | 45a290e3 | 2026-10-06 |
| events-and-replay | reconciled (Phase D fix pass; applies RC-02, RC-04, RC-07, RC-08, RC-09, RC-31, RC-40; X-07, X-08, X-09, security m3; implementation blocked on DESIGN-R2) | 45a290e3 | 2026-10-06 |
| command-request-and-resolution | Phase D fix pass applied (2026-10-06): RC-41, security B2/M4/m8 | 45a290e3 | 2026-10-06 |
| conversations-transcripts-anchors | draft (Phase C; RC-02, RC-06, RC-07 applied) | 45a290e3 | 2026-10-06 |
