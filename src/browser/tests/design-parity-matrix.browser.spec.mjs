import { expect, test } from '@playwright/test'
import { PARITY_MATRIX, openParityPair, expectDesignParity, capturePairEvidence, loadAllowlist, applyAllowlist } from '../support/design-parity.mjs'

for (const cell of PARITY_MATRIX) {
  const name = `${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}-${cell.reducedMotion ?? 'normal'}`
  test(name, async ({ browser }) => {
    const pair = await openParityPair(browser, cell)
    try {
      // Compare the supported four-link base shell; enabled Experiments is
      // covered separately by the cutover navigation test.
      expect(process.env.AIUR_BROWSER_FIXTURE_MODE).toBe('base-navigation')
      await expect(pair.product.locator('.sidenav-nav a.snav')).toHaveCount(4)
      await expect(pair.product.getByRole('link', { name: 'Experiments', exact: true })).toHaveCount(0)
      const baseNavigation = await loadAllowlist(new URL('../support/design-parity-base-navigation.json', import.meta.url))
      pair.allowlist = pair.allowlist.filter(entry => entry.id !== 'experiments-nav').concat(baseNavigation)
      await applyAllowlist(pair, cell)
      await capturePairEvidence(pair)
      await expectDesignParity(pair, { name })
    } finally { await pair.close() }
  })
}
