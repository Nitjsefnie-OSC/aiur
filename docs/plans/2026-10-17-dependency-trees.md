# Dependency chains and whole-tree view

Implement MP-E8-C9-T11 using the frozen research ticket at commit 6732f5f9f448b1857a9643993849635f85321e19.

1. Pure graph unit: `src/priv/static/build-home/chains.js` and `src/browser/tests/build-home-chains.test.mjs`. Preserve the design's DFS insertion order and cycle-cut depths using explicit stacks. Count unloaded first hops and unknown missing links; ignore undated history in Fit; preserve unknown node values. Test cycles, self-loops, 20,000 rows, fixture oracle parity, missing links and nullable fields.
2. Interaction unit: `src/priv/static/build-home/trees.js`, with small wiring changes in render, shell, URL and hook modules. Use existing lifecycle timers/listeners/frames; keep the design's timings, geometry and classes. Fit uses history paging and cancellation. Reapply locks and overlays after live updates, retaining scroll and focus. Add chains/diff fixtures and `src/browser/tests/build-home-chains.browser.spec.mjs` for gating, hover, lock/fit/tree, live changes, touch, Escape, focus and teardown; compare overlay geometry to the frozen design.

Blocker #3145 is integrated at c4d059a240b7cd8e823ebdec2d2741cea854e1b9 and remains open. Keep the PR draft against its branch until it merges. Run relevant Node/browser tests, mutation checks in an isolated worktree, lint and pre-PR gates. Document the reachable dependency surface in the existing build guide; record any operator-only check honestly in the PR.

Fit discovers undated unloaded direct links through at most three existing one-day history pages per action. It also stops when the links load, paging ends, a page fails/makes no progress, or the user changes the lock. Known loaded dates still use ensureFrom; the client never guesses an unloaded row's date. Intake retains unloaded child ids from the index alongside reverse links derived from loaded deps.
