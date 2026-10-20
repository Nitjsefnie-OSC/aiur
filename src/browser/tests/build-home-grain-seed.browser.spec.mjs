import { expect, test } from '@playwright/test'
import { openDesign, parityContextOptions } from '../support/design-parity.mjs'

const cell = { dataset: 'live', viewport: { width: 1440, height: 1000 }, theme: 'dark', palette: 'gruvbox', reducedMotion: 'no-preference' }

test('harness self-check: design grain noise has a fixed seed', async ({ browser }) => {
  const context = await browser.newContext(parityContextOptions(cell))
  try {
    const page = await context.newPage()
    await openDesign(page, cell)
    for (const selector of ['.bd-now', '.ax-uc', '.bd-lanes']) {
      const images = await page.locator(selector).evaluateAll(els => els.map(el => getComputedStyle(el, '::after').backgroundImage))
      expect(images.length, `${selector} grain`).toBeGreaterThan(0)
      for (const image of images) expect(image, `${selector} grain seed`).toContain("feTurbulence seed='1'")
    }
  } finally { await context.close() }
})
