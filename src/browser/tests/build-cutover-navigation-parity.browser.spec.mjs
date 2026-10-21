import { test } from '@playwright/test'
import { PARITY_MATRIX, expectDesignParity, capturePairEvidence } from '../support/design-parity.mjs'
import { openCutoverParityPair } from '../support/cutover-parity.mjs'

for (const cell of PARITY_MATRIX.filter(cell => cell.dataset === 'live')) {
  const name = `${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}-${cell.reducedMotion ?? 'normal'}`
  test(name, async ({ browser }) => {
    const pair = await openCutoverParityPair(browser, cell)
    try {
      await capturePairEvidence(pair)
      await expectDesignParity(pair, { name, region: 'aside.sidenav', clipToViewport: true })
    } finally { await pair.close() }
  })
}
