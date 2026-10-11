---
pageClass: cli-reference
---
# CLI development commands

## `aiurdev`, for developing Aiur itself

`scripts/aiurdev` is **only** for working on Aiur's own source. It builds and runs a local development release from a checkout, entirely separate from the `aiur` you installed with npm, bun, or Homebrew. If you are using Aiur rather than changing it, you never need this section.

Apart from the commands below, `aiurdev` executes the same launcher engine as `aiur`; it is one CLI surface, not two products.

| Syntax | Default or important interaction | Runnable example |
| --- | --- | --- |
| `scripts/aiurdev build` | Rebuilds the local release before the next run. The installed `aiur` does not have this command. | `scripts/aiurdev build` |
| `scripts/aiurdev build --deps` | Rebuilds dependencies as part of the development build. | `scripts/aiurdev build --deps` |
| `scripts/aiurdev upgrade` | Refuses because the development shim runs source from this checkout; install the npm CLI and use `aiur upgrade` instead. | `scripts/aiurdev upgrade` |
| `scripts/aiurdev --test` | Resets the first pinned sandbox ticket, then runs the foreground harness scoped to that ticket for startup cleanup and polling. It first stops the keyed live daemon and is blocked from agent workspaces. | `scripts/aiurdev --test --force` |
| `scripts/aiurdev --test3` | Resets the pinned blocker-chain tickets, then runs scoped to those tickets for startup cleanup and polling. It stops the keyed live daemon, permits the remote scenario, preserves logs unless `--clear` is added, and is blocked from agent workspaces. | `scripts/aiurdev --test3` |
| `scripts/aiurdev --clear` | Requires debug mode; deletes only this instance’s log roots with a recorded, dead owner PID. Live, foreign, and unmarked roots are preserved. | `scripts/aiurdev --debug --clear` |
| `scripts/aiurdev --allow-remote` | Permits the remote test scenario. | `scripts/aiurdev --test3 --allow-remote` |

`aiurdev` refuses every invocation from an existing tmux session because Aiur starts its own tmux socket. It pins the opencode binary selected by the release and preserves a complete existing release for control commands, so a control command does not rebuild a daemon it is about to contact.

### Which checkout `aiurdev` targets

`aiurdev` resolves its target repository from its own path, following symlinks first, so a globally symlinked `aiurdev` works from any directory. Set `AIUR_REPO_ROOT` to name a target explicitly and that choice always wins.

When the script path and current directory point at different checkouts, command intent decides the outcome.

| Command type | Outcome |
| --- | --- |
| `build`, `restart`, or bare run | Refuses with exit code 64 and prints both roots plus the two ways to resolve the mismatch. |
| Control or RPC command, including `status`, `stop`, `watch`, `units`, and `executor-answer` | Runs against the script's checkout, names that checkout, and reuses its release without rebuilding. |

| `AIUR_BUILD_STAMP` field | Why it matters |
| --- | --- |
| Repository root and source commit | A commit mismatch marks the release stale after operations such as `git switch`. |
| Dirty-tree flag and build time | Records the exact development build provenance. |

`aiur` accepts a path to a workflow configuration as the final run argument. Every fresh `aiur` or `aiurdev` launch prints `Config: /absolute/path` after startup, naming the configuration selected by discovery or that explicit argument. An already-running background no-op does not load or print a configuration.
