# merge_policy

The top-level policy is validated and displayed by `aiur status` and `aiur capabilities`; main watching reports base-branch CI when enabled.

| Key | Type | Default | Controls |
| --- | --- | --- | --- |
| `merge_policy.ci` | string | `wait` | `wait` (the only mode) requires full CI before merge. |
| `merge_policy.local_tests` | string | `partial` | `all`: full local suite; `partial`: tests relevant to the change, falling back to the full suite when selection is unsafe; `none`: compile and format only. |
| `merge_policy.full_ci_labels` | array | `[main-fix]` | Case-insensitive PR or ticket labels requiring full CI regardless of `ci`. |
| `merge_policy.full_ci_paths` | array | `[]` | Changed-path globs (`*`, `**`, `?`) requiring full CI regardless of `ci`; matches deleted paths too. |
| `merge_policy.premerge_checks` | array | `[]` | Commands to run on the merge result before merging. |
| `merge_policy.attribution_scan` | boolean | false | Enables the premerge AI-attribution scan of the PR title and body. |
| `merge_policy.main_watch.enabled` | boolean | false | Watches completed CI on the configured base branch through webhooks and polling. |
| `merge_policy.main_watch.workflows` | array | `[]` | Workflow names to watch; empty means every workflow on the base branch. |
| `merge_policy.main_watch.on_red` | string | `alert` | `alert` reports failed CI; `dispatch_fixer` requests a fixer ticket and priority dispatch. |
| `merge_policy.main_watch.fixer_label` | string | `main-fix` | Label for fixer tickets and their full-CI requirement. |
| `merge_policy.main_watch.canary_minutes` | integer | 45 | Minutes without a completed watched run before rerunning the newest cancelled run; requires Actions write permission, otherwise raises attention. `0` disables. |
| `merge_policy.main_watch.red_fallback_minutes` | integer | 0 | Optional full-CI wait after main stays red this many minutes; absent/`0` disables, `60` enables a one-hour threshold; the merge-policy consumer enforces the threshold using the watcher’s retained state. |

`on_red: dispatch_fixer` requires `fixer_label` in `full_ci_labels`. Lists reject blank entries; canary and red-fallback minutes must be nonnegative integers. Invalid values name the dotted config path.

`aiur status` shows `main=unknown` or a color with the completed-run SHA and age, such as `main=green sha=abc123 age=180s`. Red includes its full UTC start date and any fixer ticket. Failed polls show `main=unavailable last_known=green sha=abc123 age=180s`; missing metadata stays `unknown`.

New failure signatures emit `system.main.ci.failed`; known-flake-only failures emit `system.main.ci.flaked`. A later green SHA emits `system.main.ci.failed.resolved`. State and failure history survive daemon restarts.

Actions read permission is required to attribute checks to workflows. Failed or denied reads retain the last known state and emit `system.main.ci.unavailable` once until the next successful observation.

Named workflows must run on every base push. For example, `[ci, "Publish Docker Image"]` works when both run on every push; a path-filtered workflow can leave status on an older SHA. Merge-queue commits without push runs are skipped. The first Actions page must reach back to the oldest commit in the 20-commit window.

Status reports `watcher=running`, `watcher=unavailable` or `watcher=not_running` separately from the configured flag. Enabling watching after boot requires restarting the daemon to start its watcher.
