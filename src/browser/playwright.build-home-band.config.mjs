import config from './playwright.design-parity.config.mjs'

// PRs keep one width and two representative datasets across every theme/palette.
// The unfiltered design config remains the full 104-case merge-queue/nightly matrix.
export default {
  ...config,
  fullyParallel: true,
  workers: 2,
  grep: /band pixels and card geometry: (live|offline) 390 |mobile composed headers without masks: (live|offline) /
}
