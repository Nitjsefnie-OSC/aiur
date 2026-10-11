---
pageClass: cli-reference
---
# CLI launch and setup

Without local config, `aiur` and `aiurdev` use `~/.aiur/config`. Global launches announce the config and `origin` target, then ensure workflow/marker and complexity labels, without model labels. `aiur init` provisions `flake` for [CI failure evidence](/apis/github#ci-failure-evidence).

Keep shared credentials in `~/.aiur/.env`; exported values win. If required labels are missing and credentials lack Issues write access, startup fails before agents start. Omit `tracker.github.repo` for portable global settings; a conflicting explicit repo fails safely. Local config takes precedence.

`aiur` exists so an **agent can run Aiur on your behalf**; humans can type the commands or watch the TUI and dashboard while their Executor agent drives.

| Design goal | Result |
| --- | --- |
| Executor access | An agent can operate a run from a terminal without asking a human to type commands. |
| Surface parity | The CLI targets feature parity with the [GUI](/guide/gui) and [TUI](/guide/tui). |

Run the command from the repository that owns the run. An instance is keyed to that project, so control commands address that repository's daemon.

## What the CLI does

| Job | Commands | Notes |
| --- | --- | --- |
| Start or attach | `aiur`, `aiur run` | Bare `aiur` attaches to this repository's live session when one exists; otherwise foreground gives the TUI board and chat panes. Background is headless unless launched with `--interactive`. |
| Inspect live state | `status`, `agents`, `watch`, `alerts`, `usage`, `github-cost`, `github-usage` | Read-only reports from the running daemon. |
| Operate the fleet | `set max-agents`, `pause`, `resume`, `message`, `reset-budget`, `workspace-recover`, `stop`, `restart` | Steers a live run and recovers an exactly identified workspace hold after the daemon proves provider exit. |
| Mirror a dashboard page | `units`, `commands`, `build-orders`, `queue show`, `analytics` | Read-only terminal forms of the dashboard pages. |
| Act on durable records | `ask`, `asks`, `executor-answer`, `executor-escalate`, `executor-moot`, `executor-emit`, `listen`, `findings` | Decision inbox, Executor events, and findings ledger. |

Background mode is the shape that matters for an agent Executor. `aiur --bg` starts the daemon with no board and no panes, the dashboard stays up, and every command below reads and writes the same live state through that detached daemon.

## Start, initialize, and queue

| Syntax | Default or important interaction | Runnable example |
| --- | --- | --- |
| `aiur` | Attaches to this repository's live tmux session when one exists; otherwise starts a foreground interactive run. Attachment does not create a second run or take teardown ownership, so detaching leaves the daemon healthy. | `aiur` |
| `aiur run` | Explicit foreground launch form. `--bg` makes it headless; `--interactive` restores terminal panes in a background session. | `aiur run --bg` |
| `aiur init` | Interactive setup detects the tracker and toolchain, writes `.aiur/config`, `.aiur/hooks`, `.aiur/prompt.md`, `.aiur/alerts`, and prewarm support when selected, then creates the repository state-node tree and warms the base build. For GitHub trackers it verifies repository access before offering CI and label setup, with token-specific recovery guidance when an organization-owned repository is hidden by GitHub's authorization-masked 404; it then asks once whether to use an App for the daemon and defaults to No (`GITHUB_TOKEN`), and choosing Yes points to the existing App setup guide. It also asks whether to enable Stream Deck voice input with ElevenLabs speech-to-text; answering yes writes the `elevenlabs` section, defaulting the key to the `$ELEVENLABS_API_KEY` environment reference. When the repository has no `.aiur/config` but `~/.aiur/config` exists, it asks whether to resume the global config or create a repo-local one: repo-local is the default when the checkout's `origin` remote differs from the global config's `tracker.github.repo`, and global when they match, no repo is pinned, or no `origin` remote can be detected. For GitHub repositories, Aiur waits for required CI checks before merging agent work, so setup checks whether the repository has a pull-request workflow and required checks. A missing configured branch stops setup with guidance to update `tracker.base_branch`; access errors also stop before a lower-priority CI scaffold question. If a workflow is created, replace its failing placeholder with the real test command, require `ci / required` in GitHub Settings → Rules → Rulesets for the base branch, then rerun `aiur init`. Accepted and declined setup choices are saved; resuming setup shows those selections and skips the recorded questions, while a choice absent from older config is still offered. Claude adapter setup leaves a satisfying installed version unchanged and uses a version-safe source when installation is needed. | `aiur init` |
| `aiur init --force` | Recreates generated configuration for the location you choose at the first prompt; picking repo-local leaves an existing `~/.aiur/config` untouched. `--force` explicitly re-runs setup choices, including recorded declines. Re-running without it preserves existing scaffold files and recorded declines. | `aiur init --force` |
| `aiur login <harness> <name> [--dir <path>]` | Creates or adopts an isolated profile for Claude or Codex and starts its interactive login. API-key harnesses (`kimi`, `deepseek`, `openrouter`) require the named `*_API_KEY__<NAME>` entry in `~/.aiur/.env`; the secret is never stored in the account registry. | `aiur login codex work` |
| `aiur --harness NAME` | Legacy parser option; does not change the configured agent harness. Use the workflow agent configuration. | `aiur --harness codex` |
| `aiur accounts [<harness>] [--json]` | Lists registered accounts and supported identity/usage observations without printing credentials, with `remaining_percent` (the binding window's usage left) for every backend it can read. Codex usage comes from the usage ledger when the backend has one account (`freshness=ledger`, with `age_ms`); a reading older than `agent.headroom_reading_max_age_seconds` shows `freshness=stale_ledger` and no numbers. A Claude meter reading past the same age shows `freshness=stale` and keeps its numbers and `age_ms`. `muse` has one native login and does not support isolated accounts. | `aiur accounts codex --json` |
| `aiur logout <harness> <name> [--purge]` | Removes an account from the machine registry. Its profile remains unless `--purge` is specified; `default` is protected. | `aiur logout codex work` |
| `aiur --todo 142 143` | Requires a running daemon and one or more numeric IDs, with commas also accepted. A stopped daemon exits nonzero. | `aiur --todo 142,143` |
| `aiur --todo 142 --only` | Queues the named IDs and asks GitHub to remove `agent:todo` from other pending tickets. It is GitHub-only, is bounded to 50 cleanup targets, and stops after three consecutive rate-limit failures. Removing `agent:todo` from a promoted queue member creates an external hold, cleared with `aiur queue release`. Cleanup is skipped if a requested ID fails, so the operation does not silently dequeue work after a bad request. | `aiur --todo 142 --only` |
| `AIUR_CONTROL_RPC_TIMEOUT_SECONDS=<n> aiur --todo …` | `--todo` sizes its deadline by the request, rather than using the shared 10-second control-RPC deadline. Queue add/remove also use 15s plus 3s per ID and honor this override; their timeout leaves the outcome unknown. Its default window is 15s, plus 3s per requested ID, plus 90s when `--only` is given. The daemon self-limits 10 seconds inside that window: a run it cannot finish stops itself, names the tickets it never reached, and exits nonzero, so the outcome is always definite rather than "unknown". This variable overrides the whole window when set to a positive integer; a zero or malformed value is ignored in favor of the sizing above. | `AIUR_CONTROL_RPC_TIMEOUT_SECONDS=300 aiur --todo 142 --only` |
| `aiur --bg` | Starts detached headless execution. Against an existing live session it exits successfully and names bare `aiur` as the attach command. A default headless session has no agent-list or chat panes; use the dashboard or control commands. | `aiur --bg` |
| `aiur --debug` | Enables debug logs and durable chat-pane recording for this run. Analytics capture does not depend on `--debug`. | `aiur --debug` |
| `aiur --pause` | Cold-starts with the global provisioning switch paused. | `aiur --pause` |
| `aiur --max-agents 6` | Launch-only session cap. It wins over `agent.max_concurrent_agents`; Aiur warns when it exceeds that setting. `status` identifies the active binding. | `aiur --max-agents 6` |
| `aiur --interactive` | Requests the terminal UI, including from a background launch. | `aiur --bg --interactive` |
| `aiur --headless` | Requests no terminal UI. Background launch injects it unless `--interactive` is present. | `aiur run --headless` |
| `aiur --executor` | Marks the run as Executor-owned and registers its renewing principal in `executor-roster`. Recording is **not** gated on this flag: every run arms the supervised `executor.#` listener and the wake inbox, so PR-lifecycle, CI and attention records exist for a later agent to replay. What the flag adds is authority — created and deferred Commands are raised as needs-attention alerts only on an Executor-owned run. On startup it also records an informational, retrospective daemon heartbeat gap when the durable lifecycle journal confirms a clean stop or an unclosed prior start. This is not live monitoring: no alert is emitted while Aiur is stopped; the notice appears on the next Executor startup. `LISTENER absent` is therefore always a fault. | `aiur --bg --executor` |
| `aiur --no-dashboard` | Suppresses the dashboard listener in foreground or background mode. It is rejected for Remote Control because its lifecycle hooks need the listener. | `aiur --bg --no-dashboard` |
| `aiur --host 127.0.0.1` | Overrides the dashboard bind host. A non-loopback host requires dashboard credentials. | `aiur --host 127.0.0.1` |
| `aiur --port 4000` | Overrides the HTTP port. `0` lets the OS choose a free port. | `aiur --port 4000` |
| `aiur --logs-root /var/log/aiur` | Overrides the daemon log root for this launch. | `aiur --logs-root /var/log/aiur` |
| `aiur --i-understand-that-this-will-be-running-without-the-usual-guardrails` | Required by the release parser; the launcher inserts it for normal run commands. | `aiur run --i-understand-that-this-will-be-running-without-the-usual-guardrails` |
| `aiur --version` | Prints both the release version and shell dispatcher version without contacting or claiming a running daemon. If they differ, update `aiur-cli` before trusting that newer subcommands are available. | `aiur --version` |

Background runs persist daemon Logger messages at `<logs-root>/log/aiur.log` without `--debug`. `--debug` additionally enables debug-level messages. The default background root is `~/.aiur/logs/<launch-id>/`; `log/boot.out.log` captures release stdout and stderr.

`aiur status` prints `MERGE POLICY` configuration; `aiur capabilities` reports `ci=<mode> local_tests=<mode>` ([merge policy](/reference/merge-policy)). Status also lists `CI WAIT` tickets with PR, recovery state and failing checks, including tickets without workers.

`aiur status` shows degraded CODEOWNERS trust with cause and age ([GitHub trust](/apis/github#who-aiur-trusts)). With ready work and free slots, it names preflight holds, stale polling, `awaiting dispatch`, or empty-cycle reasons and age. Prewarm holds keep their cause; unexplained empty cycles report `unknown`.

The `POLL` line reports the age and freshness of the last dispatch poll attempt. A daemon that has not started a dispatch poll says so; unavailable age is never rendered as zero.

On Linux, `aiur init` probes the Codex command sandbox when Codex is selected. A failure shows the command output and offers a retry; see the [Linux setup steps](/guide/quick-start#codex-on-linux).

Event counters, subscriptions, session handles and the alert ledger survive restarts in instance- and repository-scoped runtime state. Central alert and event-publication audit logs remain per launch; `--logs-root` controls those logs.

On upgrade, session handles and subscriptions start empty once, just as they previously did on every restart; state saved from that boot onward is durable. The event counter seeds above the maximum across all launches' counters, logs, the journal and the clock; the alert ledger adopts only its exact project-scoped filename and backfill marker once.

Launch mode determines which interfaces remain available:

| Launch choice | Behavior |
| --- | --- |
| Foreground | Shows the terminal board and chat panes. A later bare `aiur` from the same repository reattaches to that session. |
| `--bg` | Runs headlessly but keeps the dashboard unless paired with `--no-dashboard`. |
| Host precedence | `--host` wins over `server.host`, which wins over `AIUR_DEFAULT_DASHBOARD_HOST` or the `127.0.0.1` default. |
| Startup output | Reports the usable dashboard URL and effective bind host and port. |

When an unknown subcommand is routed through a release built from a checkout, Aiur also compares the dispatcher and checkout package versions. If the dispatcher is older, the error tells you to update `aiur-cli` instead of presenting the command as simply unavailable.
