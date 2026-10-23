import { test, expect } from '@playwright/test'
import { PARITY_VIEWPORTS, selectProductDataset } from '../support/design-parity.mjs'
import { openModalPair } from '../support/build-home-modal-pair.mjs'
import { compareRegion } from '../support/build-home-region-parity.mjs'

test.setTimeout(180_000)
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark', 'light']) for (const palette of ['aiur', 'gruvbox']) {
  test(`unfiled modal elements ${viewport.viewport.width} ${theme} ${palette}`, async ({ browser }) => {
    const pair = await openModalPair(browser, { ...viewport, theme, palette, dataset: 'live' }, { productPending: true })
    try {
      await selectProductDataset(pair.product, 'unfiled')
      await pair.product.reload()
      await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-generation', /\d+/)
      const row = await pair.product.evaluate(async () => (await import('/build-home/state.js')).ctx.D.plan.find(t => t.src?.kind === 'pack'))
      expect(row.id).toBe('pack:build-plan/BP-645')
      await pair.design.evaluate(() => window.AiurBuild.open('AIUR-645'))
      await pair.product.evaluate(async id => (await import('/build-home/modal/frame.js')).openById(id), row.id)
      for (const side of ['design', 'product']) await pair[side].locator('#tk-modal').evaluate(el => el.getAnimations().forEach(a => a.finish()))
      for (const selector of ['.bm-st', '.bm-src', '#tk-head .bm-ib[data-a="none"]']) {
        await compareRegion(pair, { name: `unfiled.${viewport.viewport.width}.${theme}.${palette}.${selector}`, region: selector })
      }
      for (const side of ['design', 'product']) await pair[side].locator('#tk-head .bm-ib[data-a="none"]').hover()
      await compareRegion(pair, { name: `unfiled.docs-hover.${viewport.viewport.width}.${theme}.${palette}`, region: '#tk-head .bm-ib[data-a="none"]' })
    } finally { await pair.close() }
  })
}
