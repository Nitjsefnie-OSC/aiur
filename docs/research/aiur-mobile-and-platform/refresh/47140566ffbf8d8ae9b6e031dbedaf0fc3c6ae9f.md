# Initial refresh draft — 47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f

- Range: 45a290e3053423100a73b534c620fdd12ebe11ad..47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f.
- Research pack: e9785e0eef0195f86f710552200a45d2de01fdef; ledger publication: b90d65c80e2f320bc15fd9c7b30b63e791ef9a85.
- Owner: coordinator / Executor; worker draft prepared on 2026-10-14 for #3339.
- State: **corrected worker draft authorized for research commit**; semantic reviews remain OPEN. Global refresh cursor remains 45a290e3.

## Results

21 file moves; 8773 citations; GONE: 139, LINES-CHANGED: 698, LINES-SHIFTED: 506, MOVED: 43, OK: 3348, UNRESOLVED: 4039
16 migration rows; 1073 size-owner outcomes.

246 verified mechanical citations (line ranges byte-compared, bare paths existence-checked) drafted across 180 MP documents (including mirrors). Existing base_sha values are preserved. 2486 non-OK entries in the 45a290e3-based MP scope remain for semantic/path review; newer-baseline E6 tickets are deliberately excluded from old-baseline citation edits. The raw report includes all pack docs and U8, not just MP worker edits.

The tool cannot promise all-OK results after replaying shifted coordinates against the same old-to-new range. Same-range replay measures drift against old coordinates; validate destination code directly. No all-OK replay is claimed.

## Acceptance remaining

- Executor reviewed the draft and authorized the worker to correct, commit and push it on research/refactor-findings; no main change.
- Feature owners own the [complete open-review lists](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/open-reviews.md): 2486 old-baseline entries and 4039 unresolved entries, grouped and assigned per MP feature. These populations overlap. Feature owners review changed/gone/split/unresolved citations and proposed migration targets. An invalidated design retains its existing blockers and adds REFRESH-<ticket>-<sha>.
- Migration §4 PR-08 records merged router split e777b37e and six real route paths, verified at this head. Remaining rows require their move owners; no row is marked shipped from file survival alone.
- Reconcile real tracker starts with the prospective nine-ticket RC-23 inventory; this draft does not invent admission history or worker scope.
- Cursor advances only after all required owner reviews are accepted. Contract owners alone change contract status.

## Evidence

- Existing C11-T01 CLI fixture suite: python3 scripts/test_plan_refresh.py — 17 tests pass. No new tests or production code.
- Three mechanically refreshed citations are byte-compared at old and target commits; see [worker validation](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/validation.md). No TUI/runtime feature is claimed.
- [Hook preservation](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/hooks.md), [all 14 contracts](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/contracts.md), [RC-23 inventory](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/admissions.md).

## Raw tool output

The following parts concatenate byte-for-byte to the raw report. Each is <=440 lines; total 9949 lines.

- [part 1](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-01.md)
- [part 2](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-02.md)
- [part 3](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-03.md)
- [part 4](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-04.md)
- [part 5](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-05.md)
- [part 6](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-06.md)
- [part 7](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-07.md)
- [part 8](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-08.md)
- [part 9](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-09.md)
- [part 10](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-10.md)
- [part 11](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-11.md)
- [part 12](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-12.md)
- [part 13](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-13.md)
- [part 14](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-14.md)
- [part 15](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-15.md)
- [part 16](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-16.md)
- [part 17](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-17.md)
- [part 18](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-18.md)
- [part 19](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-19.md)
- [part 20](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-20.md)
- [part 21](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-21.md)
- [part 22](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-22.md)
- [part 23](./47140566ffbf8d8ae9b6e031dbedaf0fc3c6ae9f/raw-23.md)

## Executor correction pass

- Reviewed 247 citations with zero wrong; corrected C8-T03 current line count and labelled its original reference counts pre-move at 45a290e3 in both copies.
- Restored all nine E6 original size_owner rationales; prospective decisions remain in admissions.md only. Each ticket records that real admission happens at ticket start.
- Every mechanical refresh stamp names its verified citations.
- Full feature-owned open lists preserve the old cursor; no semantic review is claimed closed.
