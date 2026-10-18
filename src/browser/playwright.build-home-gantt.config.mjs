import config from './playwright.design-parity.config.mjs'

// Design comparisons stay in disposable artifacts. Unknown-value elements have
// no design counterpart, so their reviewed regression captures are durable.
export default {
  ...config,
  projects: [
    { name: 'gantt', testMatch: 'build-home-gantt.browser.spec.mjs' },
    {
      name: 'gantt-unknown',
      testMatch: 'build-home-gantt-unknown.browser.spec.mjs',
      snapshotPathTemplate: '{testDir}/build-home-gantt-snapshots/{arg}{ext}'
    }
  ]
}
