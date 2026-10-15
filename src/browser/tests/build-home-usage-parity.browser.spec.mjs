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

import { pausedAnimations, compareRecords, runOn } from '../support/build-home-motion.mjs'
for (const theme of ['dark','light']) test(`usage popover and grain ${theme}`, async ({ browser }) => {
  const pair = await openParityPair(browser, { ...PARITY_VIEWPORTS[0], theme, palette:'aiur', dataset:'live' }, { productPending:true, motion:true })
  try {
    for (const selector of ['.mdl .ax-ln', '.api .ax-ln:nth-child(2)']) {
      const records=[]
      for (const side of ['design','product']) {
        await pair[side].locator('body > .ax-pop').evaluate(el => { el.classList.remove('show'); getComputedStyle(el).opacity })
        await pair[side].clock.runFor(128)
        await pair[side].locator(selector).first().dispatchEvent('mouseover')
        const animations=await pausedAnimations(pair[side],'body > .ax-pop')
        expect(animations.map(a => a.name).sort()).toEqual(['opacity','transform'])
        records.push({name:'usage.popover',samples:animations})
      }
      expect(compareRecords(records[0],records[1])).toEqual([])
      for (const side of ['design','product']) await pair[side].evaluate(() => window.motionAnimations.forEach(a => { a.currentTime=Number(a.effect.getTiming().duration) }))
      await expectDesignParity(pair,{preserveAnimations:true,name:`popover-${selector.startsWith('.mdl') ? 'model' : 'gql'}-${theme}`,region:'body > .ax-pop.show'})
    }
    const design=await runOn(pair.design,'grain.static',{selector:'.ax-uc'})
    const product=await runOn(pair.product,'grain.static',{selector:'.ax-uc'})
    expect(compareRecords(design,product)).toEqual([])
    expect(product['ax-uc'].after.display).toBe(theme === 'light' ? 'none' : 'block')
  } finally { await pair.close() }
})
