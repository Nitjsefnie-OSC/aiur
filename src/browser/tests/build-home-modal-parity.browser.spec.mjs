import { test, expect } from '@playwright/test'
import { PARITY_VIEWPORTS } from '../support/design-parity.mjs'
import { openModalPair } from '../support/build-home-modal-pair.mjs'
import { compareRegion } from '../support/build-home-region-parity.mjs'

// Offline reuses the live rows but prevents the design's mock conversation timer changing progress.
test.setTimeout(180_000)
// Each matrix cell exercises seven state headers against the frozen design.
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark', 'light']) for (const palette of ['aiur', 'gruvbox']) {
  test(`modal headers and frame ${viewport.viewport.width} ${theme} ${palette}`, async ({ browser }) => {
    const pair = await openModalPair(browser, { ...viewport, theme, palette, dataset: 'offline' }, { productPending: true })
    try {
      await expect(pair.product.locator("#build-root")).toHaveAttribute("data-build-generation", /\d+/)
      const rows = await pair.product.evaluate(async () => {
        const { ctx } = await import('/build-home/state.js')
        return ['active', 'paused', 'command'].map(state => ctx.D.now.find(t => t.agent.state === state))
          .concat(['done', 'failed'].map(status => ctx.D.hist.find(t => t.status === status)), ctx.D.plan.find(t => t.wave < 5), ctx.D.nq[0])
      })
      for (const t of rows) {
        expect(t).toBeTruthy()
        await pair.design.evaluate(id => window.AiurBuild.open('AIUR-' + id), t.id)
        await pair.product.evaluate(async id => (await import('/build-home/modal/frame.js')).openById(id), t.id)
        // Only the frame/header belongs to this ticket; body ports have their own successors.
        for (const side of ['design', 'product']) await pair[side].locator('#tk-body').evaluate(el => { el.style.visibility = 'hidden' })
        await compareRegion(pair, { name: `modal.head.offline.${t.id}.${viewport.viewport.width}.${theme}.${palette}`, region: '#tk-head' })
        const geometry = []
        for (const side of ['design', 'product']) geometry.push(await pair[side].locator('#tk-modal').evaluate(el => {
          const b = el.getBoundingClientRect(), css = getComputedStyle(el)
          return { width: b.width, height: b.height, border: css.border, radius: css.borderRadius, shadow: css.boxShadow }
        }))
        expect(geometry[1]).toEqual(geometry[0])
      }
    } finally { await pair.close() }
  })
}
