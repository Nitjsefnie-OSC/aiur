import { test, expect } from '@playwright/test'
import { PARITY_VIEWPORTS, openParityPair, expectDesignParity } from '../support/design-parity.mjs'

for (const viewport of PARITY_VIEWPORTS) {
  for (const theme of ['dark', 'light']) for (const palette of ['gruvbox', 'aiur']) {
    const name = `loading-${viewport.viewport.width}-${theme}-${palette}`
    test(`gate: ${name}`, async ({ browser }) => {
      const cell = { ...viewport, theme, palette, dataset: 'live' }
      const pair = await openParityPair(browser, cell, { phase: 'loading' })
      try {
        await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-state', 'loading')
        // Isolate the measured host from unrelated sticky chrome and align its raster origin.
        // Preserve the real host width, viewport height, contents and production styles.
        for (const side of ['design', 'product']) {
          await pair[side].evaluate(() => document.getAnimations().forEach(a => { a.pause(); a.currentTime = 0 }))
          await pair[side].locator('.bd-vpw').evaluate(el => {
            const width = el.getBoundingClientRect().width
            Object.assign(el.style, { position: 'fixed', top: '0', left: '0', zIndex: '2147483647', width: width + 'px' })
          })
        }
        const geometry = {}
        for (const side of ['design', 'product']) geometry[side] = await pair[side].evaluate(() =>
          ['.bd-vpw', '#bd-vp', '.bd-skel', '.bd-skel i'].map(selector => [...document.querySelectorAll(selector)].map(el => ({
            selector, box: el.getBoundingClientRect().toJSON(), grid: getComputedStyle(el).gridTemplateColumns,
            width: getComputedStyle(el).width, boxSizing: getComputedStyle(el).boxSizing,
          }))))
        await test.info().attach('loading-geometry', { body: JSON.stringify(geometry), contentType: 'application/json' })
        await expectDesignParity(pair, { name, region: '#bd-vp', preserveAnimations: true })
        for (const side of ['design', 'product']) await expect(pair[side].locator('#bd-sb')).toHaveClass(/\boff\b/)
        // Hidden elements have no screenshot box; compare their host in the off state.
        await expectDesignParity(pair, { name: `c9t01-sb-off-${name}`, region: '.bd-vpw', preserveAnimations: true })
        await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-state', 'loading')
      } finally { await pair.close() }
    })
    for (const dataset of ['live', 'dense']) for (const state of ['top', 'act', 'hover', 'drag']) {
      test(`c9t01-sb-${state}-${dataset}-${name}`, () => {
        test.fixme(true, 'awaiting MP-E8-C9-T03: board content determines scrollbar geometry')
      })
    }
  }
}
