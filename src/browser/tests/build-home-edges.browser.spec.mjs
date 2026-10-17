import { test, expect } from '@playwright/test'
import { openParityPair, waitParityReady, PARITY_VIEWPORTS } from '../support/design-parity.mjs'

const cell = { dataset: 'live', ...PARITY_VIEWPORTS[0], theme: 'dark', palette: 'gruvbox' }
const paths = page => page.evaluate(() => [...document.querySelectorAll('#bd-edges path:not(.bd-eh), .bd-now-e path')]
  .map(p => `${p.parentElement.closest('.bd-now-e') ? 'band' : 'main'} ${p.getAttribute('class')} ${p.getAttribute('d')}`).sort())

test('edges are decorative for assistive tech', async ({ browser }) => {
  const pair = await openParityPair(browser, cell)
  try {
    expect(await pair.product.evaluate(() => [...document.querySelectorAll('#bd-edges, .bd-now-e')].map(el => el.getAttribute('aria-hidden')))).not.toContain(null)
  } finally { await pair.close() }
})

// B9: the design leaves `.hide` on after flow mode; the product removes it.
test('edges return after a flow to wide resize', async ({ browser }) => {
  const pair = await openParityPair(browser, cell)
  try {
    const page = pair.product
    await page.setViewportSize({ width: 390, height: 844 }); await page.waitForTimeout(600)
    await page.setViewportSize({ width: 1440, height: 900 }); await page.waitForTimeout(800)
    const edges = page.locator('#bd-edges')
    await expect(edges).not.toHaveClass(/hide/)
    expect(await edges.evaluate(el => getComputedStyle(el).opacity)).toBe('1')
  } finally { await pair.close() }
})

// B1b: same scroll offset, same rendered edges. Pending C9-T08: the product band does not hold live items yet.
test.fixme('edge path lists match the design', async ({ browser }) => {
  const pair = await openParityPair(browser, cell)
  try {
    await Promise.all([pair.design, pair.product].map(page => waitParityReady(page, 'board', page === pair.design ? 'design' : 'product', true)))
    expect(await paths(pair.product)).toEqual(await paths(pair.design))
  } finally { await pair.close() }
})
