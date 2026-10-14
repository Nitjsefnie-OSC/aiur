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
          await pair[side].locator('.bd-vpw').evaluate(el => {
            const width = el.getBoundingClientRect().width
            Object.assign(el.style, { position: 'fixed', top: '0', left: '0', zIndex: '2147483647', width: (width + 1) + 'px' })
            // Reflow after relocation so cached grid paint bounds use the new origin.
            el.getBoundingClientRect()
            el.style.width = width + 'px'
          })
        }
        await expectDesignParity(pair, { name, region: '#bd-vp' })
        for (const side of ['design', 'product']) await expect(pair[side].locator('#bd-sb')).toHaveClass(/\boff\b/)
        // Hidden elements have no screenshot box; compare their host in the off state.
        await expectDesignParity(pair, { name: `c9t01-sb-off-${name}`, region: '.bd-vpw' })
        await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-state', 'loading')
      } catch (error) {
        const ancestors = {}
        for (const side of ['design', 'product']) ancestors[side] = await pair[side].locator('.bd-vpw').evaluate(el => {
          const rows = []
          while (el) {
            const s = getComputedStyle(el)
            rows.push({ tag: el.tagName, id: el.id, classes: el.className, box: el.getBoundingClientRect().toJSON(),
              styles: Object.fromEntries(['zoom', 'transform', 'perspective', 'filter', 'opacity', 'contain', 'content-visibility', 'will-change', 'backdrop-filter', 'position'].map(k => [k, s.getPropertyValue(k)])) })
            el = el.parentElement
          }
          return { width: innerWidth, height: innerHeight, scale: visualViewport.scale, rows }
        })
        await test.info().attach('loading-ancestors', { body: JSON.stringify(ancestors), contentType: 'application/json' })
        throw error
      } finally { await pair.close() }
    })
    for (const dataset of ['live', 'dense']) for (const state of ['top', 'act', 'hover', 'drag']) {
      test(`c9t01-sb-${state}-${dataset}-${name}`, () => {
        test.fixme(true, 'awaiting MP-E8-C9-T03: board content determines scrollbar geometry')
      })
    }
  }
}
