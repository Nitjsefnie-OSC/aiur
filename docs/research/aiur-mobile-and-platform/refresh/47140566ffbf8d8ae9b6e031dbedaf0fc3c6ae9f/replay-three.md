# Plan refresh: 45a290e3053423100a73b534c620fdd12ebe11ad → 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f

## Summary counts

21 file moves; 19 citations; LINES-CHANGED: 4, LINES-SHIFTED: 4, OK: 7, UNRESOLVED: 4
0 migration rows; 4 size-owner outcomes.

Component manifest absent at 45a290e3053423100a73b534c620fdd12ebe11ad; file mode only.

## Component path map

| Component | Old globs | New globs |
| --- | --- | --- |
| accounting |  | src/lib/aiur/accounts.ex, src/lib/aiur/accounts/**, src/lib/aiur/agent/**, src/lib/aiur/provider_account_generation.ex, src/lib/aiur/provider_account_generation/**, src/lib/aiur/provider_meter_probe.ex, src/lib/aiur/provider_meter_projection.ex, src/lib/aiur/provider_meter_projection/**, src/lib/aiur/provider_meter_refresh.ex, src/lib/aiur/provider_meter_snapshot.ex, src/lib/aiur/provider_meters.ex, src/lib/aiur/provider_meters/**, src/lib/aiur/token_usage.ex, src/lib/aiur/usage/**, src/lib/aiur/usage_aggregate.ex, src/lib/aiur/usage_aggregate/**, src/lib/aiur/usage_compaction/**, src/lib/aiur/usage_envelope.ex, src/lib/aiur/usage_envelope/**, src/lib/aiur/usage_ledger.ex, src/lib/aiur/usage_ledger/** |
| agent-runner |  | src/lib/aiur/agent_compaction/**, src/lib/aiur/agent_context_presentation.ex, src/lib/aiur/agent_directory.ex, src/lib/aiur/agent_event_log.ex, src/lib/aiur/agent_runner.ex, src/lib/aiur/agent_runner/**, src/lib/aiur/agent_skills.ex, src/lib/aiur/event_publication_log.ex, src/lib/aiur/issue_context.ex, src/lib/aiur/issue_log.ex, src/lib/aiur/issue_log/**, src/lib/aiur/live_conversation.ex, src/lib/aiur/live_conversation/**, src/lib/aiur/logs/**, src/lib/aiur/prompt_builder.ex, src/lib/aiur/session_handle.ex |
| agent-sandbox |  | src/lib/aiur/agent_build_guard.ex, src/lib/aiur/agent_command_installer.ex, src/lib/aiur/agent_environment.ex, src/lib/aiur/agent_environment/**, src/lib/aiur/agent_github_guard.ex, src/lib/aiur/agent_github_guard/**, src/lib/aiur/agent_process_log.ex, src/lib/aiur/agent_resource_guard.ex, src/lib/aiur/agent_resource_guard/**, src/lib/aiur/agent_scratch.ex, src/lib/aiur/build_gate.ex, src/lib/aiur/build_gate/**, src/lib/aiur/build_gate_hold_monitor.ex, src/lib/aiur/pause_containment.ex, src/lib/aiur/process_reaper.ex, src/lib/aiur/sandbox/** |
| aiur-contracts |  | packages/aiur-contracts/** |
| aiur-style |  | packages/aiur-style/** |
| build-orders |  | src/lib/aiur/build_order/**, src/lib/aiur/build_order_funnel_health.ex, src/lib/aiur/build_orders_cli.ex, src/lib/aiur/build_progress.ex, src/lib/aiur/epic_cli.ex, src/lib/aiur_web/build_order*.ex, src/lib/aiur_web/build_order/**, src/lib/aiur_web/build_order_presenter/**, src/lib/aiur_web/live/build_order*.ex |
| build-queue |  | src/lib/aiur/build_queue.ex, src/lib/aiur/build_queue/**, src/lib/aiur/build_queue_cli.ex, src/lib/aiur_web/build_queue/** |
| commands |  | src/lib/aiur/asks.ex, src/lib/aiur/asks_store.ex, src/lib/aiur/commands.ex, src/lib/aiur/commands/**, src/lib/aiur/decision*.ex, src/lib/aiur/decision_api/**, src/lib/aiur/decision_dispatch_tasks/**, src/lib/aiur/decision_event/**, src/lib/aiur/decision_metrics/**, src/lib/aiur/decision_query/**, src/lib/aiur/decision_store/**, src/lib/aiur/supervisor_token.ex, src/lib/aiur/supervisor_token/**, src/lib/aiur_web/controllers/decision*.ex, src/lib/aiur_web/routes/decisions.ex |
| config |  | src/lib/aiur/agent_config.ex, src/lib/aiur/config.ex, src/lib/aiur/config/**, src/lib/aiur/env.ex, src/lib/aiur/env/**, src/lib/aiur/merge_policy.ex, src/lib/aiur/workflow.ex, src/lib/aiur/workflow_store.ex, src/lib/aiur/workflow_store/** |
| control-cli |  | src/lib/aiur.ex, src/lib/aiur/*_cli.ex, src/lib/aiur/affected_tests.ex, src/lib/aiur/application/**, src/lib/aiur/cli.ex, src/lib/aiur/cli/**, src/lib/aiur/control_cli/**, src/lib/aiur/daemon_lifecycle.ex, src/lib/aiur/distribution.ex, src/lib/aiur/external_content.ex, src/lib/aiur/findings.ex, src/lib/aiur/launch_state_adoption.ex, src/lib/aiur/launcher_watchdog.ex, src/lib/aiur/pr_merge.ex, src/lib/aiur/pr_merge/**, src/lib/aiur/pubsub_boot.ex, src/lib/aiur/shutdown.ex, src/lib/aiur/specs_check.ex, src/lib/aiur/test_http_guard.ex, src/lib/aiur/test_reset.ex, src/lib/aiur/test_reset/**, src/lib/aiur/test_shard.ex, src/lib/aiur/test_ticket_scope.ex, src/lib/mix/tasks/** |
| conversations |  | src/lib/aiur/agent_event_feed.ex, src/lib/aiur/agent_log.ex, src/lib/aiur/conversation/anchors.ex, src/lib/aiur/conversation/history.ex |
| dashboard-ui |  | src/lib/aiur/event_humanizer.ex, src/lib/aiur/event_humanizer_helpers.ex, src/lib/aiur_web/**, src/lib/aiur_web/routes/dashboard_pages.ex, src/lib/aiur_web/sockets/live_view.ex |
| docs-site |  | website/docs-app/** |
| event-bus |  | src/lib/aiur/agent_events.ex, src/lib/aiur/agent_pubsub.ex, src/lib/aiur/agent_pubsub/**, src/lib/aiur/events/**, src/lib/aiur/ticket_observation.ex |
| executor-attention |  | src/lib/aiur/alert_*.ex, src/lib/aiur/alert_feed/**, src/lib/aiur/alert_ledger/**, src/lib/aiur/alerts.ex, src/lib/aiur/alerts/**, src/lib/aiur/executor/**, src/lib/aiur/executor_*.ex, src/lib/aiur/executor_attention/**, src/lib/aiur/executor_wake_inbox/**, src/lib/aiur/operator_wait_log.ex, src/lib/aiur/progress_checkin/** |
| experiments |  | src/lib/aiur/experiments.ex, src/lib/aiur/experiments/**, src/lib/aiur/experiments_cli.ex |
| github |  | src/lib/aiur/allowed_contributors.ex, src/lib/aiur/allowed_contributors/**, src/lib/aiur/ci/failure_digest.ex, src/lib/aiur/ci_approval_store.ex, src/lib/aiur/codeowners.ex, src/lib/aiur/codeowners/**, src/lib/aiur/github/**, src/lib/aiur/global_config_startup.ex, src/lib/aiur/open_ticket_source.ex, src/lib/aiur/open_ticket_source/** |
| github-listeners |  | src/lib/aiur/events/branch_ref_store.ex, src/lib/aiur/events/branch_rewrite_classifier.ex, src/lib/aiur/events/comment_filter.ex, src/lib/aiur/events/github*.ex, src/lib/aiur/events/github_ci_poller/**, src/lib/aiur/events/github_comments_poller/**, src/lib/aiur/events/ls_remote_ticker.ex, src/lib/aiur/events/pr_command_scanner.ex, src/lib/aiur/events/sanitizer.ex, src/lib/aiur/main_watch.ex, src/lib/aiur/main_watch/**, src/lib/aiur/orchestrator/comment_polling*.ex, src/lib/aiur/poll_cadence.ex, src/lib/aiur/poll_cadence/**, src/lib/aiur/stacking/**, src/lib/aiur/webhooks.ex, src/lib/aiur/webhooks/**, src/lib/aiur_web/controllers/github_webhook_controller.ex, src/lib/aiur_web/github_webhook*, src/lib/aiur_web/routes/github_webhook.ex |
| harness-adapters |  | src/lib/aiur/agent_tools/**, src/lib/aiur/app_server/**, src/lib/aiur/claude/**, src/lib/aiur/codex/**, src/lib/aiur/codex_prober.ex, src/lib/aiur/coding_agent.ex, src/lib/aiur/coding_agent/**, src/lib/aiur/model_availability.ex, src/lib/aiur/model_catalog.ex, src/lib/aiur/model_discovery.ex, src/lib/aiur/model_discovery/**, src/lib/aiur/muse/**, src/lib/aiur/open_ai_compat/**, src/lib/aiur/rtk.ex, src/lib/aiur/rtk_startup_check.ex, src/priv/agent_relay.py |
| identity |  | src/lib/aiur/capabilities.ex, src/lib/aiur/capabilities/**, src/lib/aiur/identity.ex, src/lib/aiur/identity/**, src/lib/aiur_web/controllers/capabilities_controller.ex, src/lib/aiur_web/routes/capabilities.ex |
| init |  | src/lib/aiur/init.ex, src/lib/aiur/init/**, src/lib/aiur/upgrade.ex, src/lib/aiur/upgrade/** |
| kernel |  | src/lib/aiur/boot.ex, src/lib/aiur/bounded.ex, src/lib/aiur/coordination_tasks.ex, src/lib/aiur/display_sanitizer.ex, src/lib/aiur/fs.ex, src/lib/aiur/git.ex, src/lib/aiur/journal.ex, src/lib/aiur/json_safe.ex, src/lib/aiur/json_store.ex, src/lib/aiur/jsonl.ex, src/lib/aiur/local_test_evidence.ex, src/lib/aiur/opaque_identifier.ex, src/lib/aiur/os.ex, src/lib/aiur/path_safety.ex, src/lib/aiur/periodic_worker.ex, src/lib/aiur/process_exhaustion.ex, src/lib/aiur/process_identity.ex, src/lib/aiur/process_tree.ex, src/lib/aiur/protocol/**, src/lib/aiur/secret_redactor.ex, src/lib/aiur/shell.ex, src/lib/aiur/ssh.ex, src/lib/aiur/start_trigger.ex, src/lib/aiur/start_trigger/**, src/lib/aiur/system_pressure.ex, src/lib/aiur/tracker_identity.ex, src/lib/aiur/yaml.ex, src/priv/pidfd_reap.py |
| launcher |  | packaging/**, scripts/aiurdev |
| linear |  | src/lib/aiur/linear/** |
| listener-modes |  |  |
| listener-spec |  |  |
| machine-gateway |  |  |
| mobile-app |  |  |
| notification-policy |  |  |
| orchestration |  | src/lib/aiur/agent_chat.ex, src/lib/aiur/agent_queue.ex, src/lib/aiur/agent_queue_item.ex, src/lib/aiur/agent_queue_store.ex, src/lib/aiur/current_run_membership.ex, src/lib/aiur/current_run_membership/**, src/lib/aiur/dispatch_budget_store.ex, src/lib/aiur/orchestrator.ex, src/lib/aiur/orchestrator/**, src/lib/aiur/pr_ready_ledger_store.ex, src/lib/aiur/recent_merge.ex, src/lib/aiur/recent_merge/**, src/lib/aiur/recent_merge_store.ex |
| pairing-discovery |  |  |
| pr-lifecycle |  | src/lib/aiur/pr_lifecycle/** |
| projections |  | src/lib/aiur/current_run_outcome_snapshot.ex, src/lib/aiur/current_run_outcome_snapshot/**, src/lib/aiur/current_run_projection/**, src/lib/aiur/current_run_projections.ex, src/lib/aiur/current_run_projections/**, src/lib/aiur/current_run_summary.ex, src/lib/aiur/current_run_summary/**, src/lib/aiur/progress_retention.ex, src/lib/aiur/progress_tracker.ex, src/lib/aiur/projections/**, src/lib/aiur/ticket_activity.ex, src/lib/aiur/ticket_activity/** |
| push-relay |  |  |
| relay-service |  |  |
| signal |  | src/lib/aiur/log_file.ex, src/lib/aiur/perf.ex, src/lib/aiur/signal.ex |
| skills |  | .claude/skills/**, src/prompts/** |
| streamdeck-server |  | src/lib/aiur_web/controllers/streamdeck*.ex, src/lib/aiur_web/routes/streamdeck.ex, src/lib/aiur_web/sockets/streamdeck.ex, src/lib/aiur_web/stream_deck_grid.ex, src/lib/aiur_web/streamdeck*.ex, src/lib/aiur_web/streamdeck_channel/*.ex, src/lib/aiur_web/streamdeck_logs/*.ex, src/lib/aiur_web/streamdeck_projection/*.ex |
| streamdeck-sidecar |  | packages/streamdeck/** |
| telemetry |  | src/lib/aiur/background_cpu.ex, src/lib/aiur/daemon_heartbeat.ex, src/lib/aiur/daemon_heartbeat_checker.ex, src/lib/aiur/daemon_heartbeat_writer.ex, src/lib/aiur/metrics.ex, src/lib/aiur/run_telemetry.ex, src/lib/aiur/run_telemetry/**, src/lib/aiur/saturation_sentinel.ex, src/lib/aiur/supervision_health.ex, src/lib/aiur/supervision_health/**, src/lib/aiur/system_cpu.ex, src/lib/aiur/system_file_descriptors.ex, src/lib/aiur/system_load.ex, src/lib/aiur/system_memory.ex, src/lib/aiur/system_priority.ex |
| ticket-context |  | src/lib/aiur/build_order/ticket_detail*.ex, src/lib/aiur/build_order/ticket_history*.ex, src/lib/aiur/ticket_context.ex, src/lib/aiur_web/build_order/ticket_context_*.ex, src/lib/aiur_web/build_order/ticket_context_presenter/*.ex |
| tracker |  | src/lib/aiur/code_host.ex, src/lib/aiur/issue.ex, src/lib/aiur/memory/**, src/lib/aiur/optimistic_start.ex, src/lib/aiur/ticket_branch.ex, src/lib/aiur/tracker.ex, src/lib/aiur/tracker/**, src/lib/aiur/tracker_config.ex |
| tui |  | src/lib/aiur/agent_list/**, src/lib/aiur/conversations.ex, src/lib/aiur/events/debug_log.ex, src/lib/aiur/opencode/**, src/lib/aiur/opencode_theme.ex, src/lib/aiur/pane_manager.ex, src/lib/aiur/pane_manager/**, src/lib/aiur/tmux.ex, src/lib/aiur/tmux/** |
| voice-conversation |  |  |
| voice-conversation-core |  | .github/workflows/voice-converse-standalone.yml, packages/elixir/voice_converse/**, scripts/check-voice-converse-isolation.sh |
| voice-stt |  | src/lib/aiur/eleven_labs.ex, src/lib/aiur/eleven_labs/**, src/lib/aiur/voice.ex, src/lib/aiur/voice/**, src/lib/aiur_web/sockets/voice.ex, src/lib/aiur_web/voice*.ex |
| watch-apps |  |  |
| web-kit |  | src/lib/aiur_web/capability_error.ex, src/lib/aiur_web/kit.ex, src/lib/aiur_web/provider_meter_windows.ex, src/lib/aiur_web/refresh_relay.ex |
| web-shell |  | src/lib/aiur/http_server.ex, src/lib/aiur/http_server/**, src/lib/aiur/tailscale_funnel.ex, src/lib/aiur_web/controllers/*api*.ex, src/lib/aiur_web/controllers/observability*.ex, src/lib/aiur_web/endpoint.ex, src/lib/aiur_web/financial_data_access.ex, src/lib/aiur_web/router.ex, src/lib/aiur_web/routes/api.ex, src/lib/aiur_web/supervisor_auth.ex |
| workspace |  | src/lib/aiur/prewarm/**, src/lib/aiur/repo_base.ex, src/lib/aiur/repo_base/**, src/lib/aiur/workspace.ex, src/lib/aiur/workspace/** |

## PR-xx rows

| Row | Today | Status | Current locations (component) |
| --- | --- | --- | --- |

## Stale citations by ticket

| Ticket / document | Source | Citation | Status |
| --- | --- | --- | --- |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:111 | src/test/aiur/github/ | UNRESOLVED (absent at from); SPLIT? scripts/components/allowlist/github-listeners.tsv, scripts/components/allowlist/github.tsv, src/lib/aiur/main_watch/github.ex, src/lib/aiur/run_telemetry/github_facts.ex, src/lib/aiur/run_telemetry/repo_timeline/github.ex, src/lib/aiur_web/routes/github_webhook.ex, src/priv/github_merge_queue_push_guard.sh, src/test/aiur/events/github_ci_poller_base_repair_journal_test.exs, src/test/aiur/events/github_ci_poller_base_repair_test.exs, src/test/aiur/events/github_ci_poller_evaluation_test.exs, src/test/aiur/events/github_ci_poller_required_verdict_test.exs, src/test/aiur/events/github_ci_poller_stacked_base_test.exs, src/test/aiur/events/github_comments_poller_cursors_test.exs, src/test/aiur/events/github_comments_poller_outage_test.exs, src/test/aiur/events/github_comments_poller_reviews_test.exs, src/test/aiur/events/github_firehose_failure_test.exs, src/test/aiur/events/github_firehose_window_test.exs, src/test/aiur/events/github_webhook_main_watch_test.exs, src/test/aiur/events/github_webhook_ready_for_review_equivalence_test.exs, src/test/aiur/events/github_webhook_reconcile_test.exs, src/test/aiur/events/github_webhook_thread_equivalence_test.exs, src/test/aiur/events/github_webhook_wake_test.exs, src/test/aiur/init/github_and_limits_test.exs, src/test/aiur/main_watch/github_test.exs, src/test/aiur/run_telemetry/github_facts_test.exs, src/test/aiur_web/github_webhook_admission_test.exs, src/test/support/github_client_test_support.ex, src/test/support/github_webhook_receiver_case.ex, website/docs-app/.vitepress/includes/github-view-state.md |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:52 | src/lib/aiur/github/labels.ex:26 | LINES-SHIFTED :27-27 |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:56 | src/lib/aiur/github/issues.ex:1144-1155 | LINES-SHIFTED :1112-1123 |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:59 | src/lib/aiur/issue.ex:34-52 | LINES-CHANGED |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:61 | src/lib/aiur/global_config_startup.ex:81-86 | OK |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:65 | src/test/aiur/github/labels_test.exs | OK |
| MP-E1-C1-T01 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T01.md:89 | website/docs-app/concepts/ticket-lifecycle.md | OK |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:116 | src/test/aiur/github/open_issue_snapshot_test.exs | UNRESOLVED (absent at from) |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:118 | src/test/aiur/github/issues_test.exs | OK |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:119 | src/test/aiur/tracker_test.exs | UNRESOLVED (absent at from) |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:135 | website/docs-app/apis/github.md | OK |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:56 | src/lib/aiur/github/open_issue_snapshot.ex:1-82 | LINES-CHANGED |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:59 | src/lib/aiur/tracker.ex:8-32 | LINES-CHANGED |
| MP-E1-C1-T03 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T03.md:62 | src/lib/aiur/linear/tracker.ex:141-144 | LINES-SHIFTED :143-146 |
| MP-E1-C1-T04 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T04.md:103 | src/test/aiur/memory_tracker_test.exs | UNRESOLVED (absent at from) |
| MP-E1-C1-T04 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T04.md:44 | src/lib/aiur/github/issue_state.ex:14-36 | OK |
| MP-E1-C1-T04 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T04.md:56 | src/lib/aiur/tracker.ex:120-141 | LINES-CHANGED |
| MP-E1-C1-T04 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T04.md:57 | src/test/aiur/github/issue_state_test.exs:508-558 | LINES-SHIFTED :596-646 |
| MP-E1-C1-T04 | bucket-2-platform/MP-E1/tickets/MP-E1-C1-T04.md:98 | src/test/aiur/github/issue_state_test.exs | OK |

## Size owners by ticket

| Ticket | Path | Lines | Declared owner | Status |
| --- | --- | --- | --- | --- |
| MP-E1-C1-T01 | src/lib/aiur/github/issues.ex | 1239 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, re-check per RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T03 | src/test/aiur/github/issues_test.exs | 1506 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |
| MP-E1-C1-T03 | website/docs-app/apis/github.md | 820 | "GH_TRUST / GitHub access (github/issues.ex, 1248 lines; provisional, RC-23)" | MISMATCH (ledger says DOCS) |
| MP-E1-C1-T04 | src/test/aiur/github/issue_state_test.exs | 611 | "GH_TRUST / GitHub access (github/issue_state.ex; provisional, RC-23)" | MISMATCH (ledger says GH_TRUST) |

## Contract versions (metadata only)

| Contract | Status | Base main SHA | Date |
| --- | --- | --- | --- |
| identity-and-capabilities | unavailable | unavailable | unavailable |
| events-and-replay | unavailable | unavailable | unavailable |
| command-request-and-resolution | unavailable | unavailable | unavailable |
| conversations-transcripts-anchors | unavailable | unavailable | unavailable |
