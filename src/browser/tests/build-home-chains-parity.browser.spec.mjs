import { test, expect } from '@playwright/test'
import { openParityPair, expectDesignParity, PARITY_VIEWPORTS } from '../support/design-parity.mjs'
import { settleAnimations } from './support/browser-helpers.mjs'
import { prepareChainCanvas, prepareChainParity, largestRoot, hoverRoot, assertChainPaint, fitState, installFitObserver, waitForFit, treeRecord } from './support/build-home-chains-parity.mjs'

test.setTimeout(120_000)
const root = await largestRoot('live'), denseRoot = await largestRoot('dense', 'plan')
const cells = PARITY_VIEWPORTS.flatMap(v => ['dark', 'light'].flatMap(theme => ['gruvbox', 'aiur'].map(palette => ({ dataset: 'live', ...v, theme, palette }))))
for (const cell of cells) test(`P1–P4 chain pixel parity ${cell.viewport.width} ${cell.theme} ${cell.palette}`, async ({ browser }) => {
  test.setTimeout(cell.viewport.width === 390 ? 240_000 : 120_000)
  const failures = []
  // Keep independent captures when one phase differs, then fail with every actual discrepancy.
  const check = async (name, action) => { try { await test.step(name, action) } catch (error) { failures.push(error) } }
  const pixels = (pair, name, region) => check(name, async () => {
    await prepareChainParity(pair) // Fit replaces the band's ETA element.
    await expectDesignParity(pair, { name, region, preserveAnimations: pair.cell.viewport.width === 390 })
  })
  const pair = await openParityPair(browser, cell, { query: '?trees=1' })
  try {
    await prepareChainCanvas(pair)
    await prepareChainParity(pair)
    for (const page of [pair.design, pair.product]) await hoverRoot(page, root, page === pair.product)
    await check('P1 hover classes and tab position', () => assertChainPaint(pair, root, false))
    await pixels(pair, 'P1-chain-hover', '#bd-vp')
    for (const page of [pair.design, pair.product]) await page.locator('[data-lt="lock"]').click()
    await check('P2 lock classes and tab position', () => assertChainPaint(pair, root, true))
    await pixels(pair, 'P2-chain-tab', '.bd-lt')
    await pixels(pair, 'P2-chain-lock', '#bd-vp')
    for (const page of [pair.design, pair.product]) await expect(page.locator('.bd-lt.locked.show')).toHaveCount(1)
    // P4 starts from the locked P2 state; Fit must not change its backdrop inputs.
    for (const page of [pair.design, pair.product]) {
      await page.locator('[data-lt="tree"]').click()
      await settleAnimations(page, '#bd-tree')
    }
    await check('P4 node positions and scale', async () => expect(await treeRecord(pair.product)).toEqual(await treeRecord(pair.design)))
    await pixels(pair, 'P4-whole-tree', '#bd-tree')
    await expect(pair.product.getByRole('dialog', { name: 'Dependency tree' })).toBeVisible()
    for (const page of [pair.design, pair.product]) {
      await page.keyboard.press('Escape')
      await expect(page.locator('#bd-tree')).toBeHidden()
    }
    await installFitObserver(pair.product)
    for (const page of [pair.design, pair.product]) await page.locator('[data-lt="fit"]').click()
    await waitForFit(pair.product)
    await expect(pair.design.locator('.bd-lt.locked.show')).toHaveCount(1)
    const [designFit, productFit] = await Promise.all([fitState(pair.design), fitState(pair.product)])
    await check('P3 Fit URL', async () => expect(productFit.url).toEqual(designFit.url))
    await check('P3 zoom label', async () => { expect(productFit.zoom).toBeTruthy(); expect(productFit.zoom).toEqual(designFit.zoom) })
    await check('P3 scroll', async () => expect(Math.abs(productFit.scroll - designFit.scroll)).toBeLessThanOrEqual(1))
    await pixels(pair, 'P3-chain-fit', '.bd-vpw')
  } finally { await pair.close() }
  // One narrow-cell case proves continuation-row wrapping; P1–P4 above cover every cell.
  if (cell.viewport.width === 390 && cell.theme === 'dark' && cell.palette === 'gruvbox') {
    const dense = await openParityPair(browser, { ...cell, dataset: 'dense' }, { query: '?trees=1' })
    try {
      await prepareChainCanvas(dense)
      await prepareChainParity(dense)
      for (const page of [dense.design, dense.product]) {
        await hoverRoot(page, denseRoot, page === dense.product)
        await page.locator('[data-lt="lock"]').click()
        await page.locator('[data-lt="tree"]').click()
        await settleAnimations(page, '#bd-tree')
      }
      await check('P4 dense wrap rows and scale', async () => {
        const design = await treeRecord(dense.design), product = await treeRecord(dense.product)
        expect(product).toEqual(design)
        const levels = Number(design.header.match(/· (\d+) levels/)[1])
        expect(new Set(design.nodes.map(node => node.pos[1])).size).toBeGreaterThan(levels)
      })
      await pixels(dense, 'P4-dense-wrap', '#bd-tree')
    } finally { await dense.close() }
  }
  if (failures.length) throw new AggregateError(failures, failures.map(error => error.message).join('\n'))
})
