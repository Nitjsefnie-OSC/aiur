import { test, expect } from '@playwright/test'
import { dashboardCredentials } from './support/layout-worker.mjs'
import { open, reveal, tree } from './support/build-home-chains.mjs'
import { settleAnimations } from './support/browser-helpers.mjs'

// Product-only states absent from the mock design; initial pixels await DESIGN-E8 S-34 sign-off.
const states = [
  { name: 'cycle', id: '3', productOnly: true },
  { name: 'unloaded', id: '9012', productOnly: true },
  { name: 'unknown', id: '9021', productOnly: true },
]
test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', colorScheme: 'light' })
for (const width of [1440, 390]) for (const state of states) test(`product-only ${state.name} ${width}`, async ({ page }) => {
  test.info().annotations.push({ type: 'pending-sign-off', description: 'DESIGN-E8 S-34: productOnly=' + state.productOnly })
  await page.setViewportSize({ width, height: width === 390 ? 844 : 900 })
  await open(page)
  await page.locator('html').evaluate(el => Object.assign(el.dataset, { theme: 'light', palette: 'gruvbox' }))
  await reveal(page, state.id)
  // This suite freezes presentation; the interaction suite tests mouse/touch lock initiation.
  await page.evaluate(id => st.fx.lockTree(id), state.id)
  await page.locator('[data-lt="tree"]').click()
  await settleAnimations(page, '#bd-tree')
  // The phone shell can scroll the document past its fixed nav at the board end.
  await page.evaluate(() => window.scrollTo(0, 0))
  await expect(tree(page)).toHaveScreenshot(`${state.name}-${width}.png`)
})
