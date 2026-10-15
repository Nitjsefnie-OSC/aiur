import { test, expect } from '@playwright/test'
import { PARITY_VIEWPORTS, openParityPair, expectDesignParity, applyAllowlist } from '../support/design-parity.mjs'

// The board and shell are still being ported; compare the complete usage region.
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark','light']) for (const palette of ['aiur','gruvbox']) for (const count of [2,4,7]) {
  test(`usage ${viewport.viewport.width} ${theme} ${palette} n${count}`, async ({ browser }) => {
    const pair = await openParityPair(browser, { ...viewport, theme, palette, dataset:'live' }, { productPending:true, motion:true, query:`models=${count}` })
    try {
      await expect(pair.product.locator('.ax-usage')).toBeVisible()
      if (count !== 4) expect((await pair.product.request.get(`/build-control/usage?name=n${count}`)).status()).toBe(200)
      await expect(pair.product.locator('.ax-usage')).toHaveClass(new RegExp(`n${count} `))
      await applyAllowlist(pair,pair.cell)
      for (const side of ['design','product']) {
        await pair[side].evaluate(async () => {
          await document.fonts.ready
          document.body.style.background='var(--bg)'
          document.querySelectorAll('.sidenav, .ax-top').forEach(e => e.style.visibility='hidden')
          document.getAnimations().forEach(a => Number.isFinite(a.effect?.getComputedTiming().endTime) ? a.finish() : a.cancel())
          const host=document.querySelector('#bd-usage'), r=host.getBoundingClientRect()
          host.style.transform=`translate(${Math.round(r.x)-r.x}px, ${Math.round(r.y)-r.y}px)`
        })
      }
      await expectDesignParity(pair,{name:`usage-n${count}`,region:'#bd-usage'})
    } finally { await pair.close() }
  })
}
