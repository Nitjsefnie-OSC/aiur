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

// Expose original reference operations; never replace their rendering or data.
const designSource = await (await import('node:fs/promises')).readFile(new URL('../../test/fixtures/build_home/design-source/assets/build.js', import.meta.url), 'utf8')
const reference = designSource.replace('  window.AiurBuild = {', `  window.unfiledParity = {
  scroll(id) { const it = L.secs.plan.items.find(it => it.t.id === id); scrollVP(secs.plan.el.offsetTop + it.y - 160, false); update(true); },
  tree: openTree,
};\n  window.AiurBuild = {`)
const ids = Array.from({length:16}, (_,i) => 645+i)
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark','light']) for (const palette of ['aiur','gruvbox']) {
  test(`unfiled row cells ${viewport.viewport.width} ${theme} ${palette}`, async ({browser}) => {
    test.setTimeout(600_000)
    const pair = await openModalPair(browser,{...viewport,theme,palette,dataset:'live'},{productPending:true})
    try {
      await pair.design.route('**/assets/build.js*',route => route.fulfill({body:reference,contentType:'text/javascript'}))
      await pair.design.reload()
      await expect.poll(() => pair.design.evaluate(() => !!window.unfiledParity && !!document.querySelector('.bd-card'))).toBe(true)
      await selectProductDataset(pair.product,'unfiled'); await pair.product.reload()
      await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-generation',/\d+/)
      for (const num of ids) {
        await pair.design.evaluate(num => window.unfiledParity.scroll('AIUR-'+num),num)
        await pair.product.evaluate(async num => {
          const {ctx,fx} = await import('/build-home/state.js')
          const it = ctx.L.secs.plan.items.find(it => it.t.id === 'pack:build-plan/BP-'+num)
          fx.scrollVP(ctx.secs.plan.el.offsetTop+it.y-160,false); fx.update()
        },num)
        const region = `:is(.bd-card[data-id="AIUR-${num}"],.bd-card[data-id="pack:build-plan/BP-${num}"])`
        await expect(pair.product.locator(region).locator('.bd-status > span:first-child')).toHaveText('Not filed')
        await compareRegion(pair,{name:`unfiled-board-${num}`,region})
      }
      for (const page of [pair.design,pair.product]) await page.locator('[data-v="list"]').click()
      for (const num of ids) {
        const region = `:is(.lr[data-id="AIUR-${num}"],.lr[data-id="pack:build-plan/BP-${num}"])`
        await compareRegion(pair,{name:`unfiled-list-${num}`,region})
      }
      for (const page of [pair.design,pair.product]) await page.locator('[data-v="graph"]').click()
      for (const num of ids) {
        await pair.design.evaluate(num => window.unfiledParity.tree('AIUR-'+num),num)
        await pair.product.evaluate(async num => (await import('/build-home/trees.js')).openTree('pack:build-plan/BP-'+num),num)
        const region = `:is(.bd-tn[data-id="AIUR-${num}"],.bd-tn[data-id="pack:build-plan/BP-${num}"])`
        await compareRegion(pair,{name:`unfiled-tree-${num}`,region})
      }
    } finally {await pair.close()}
  })
}
