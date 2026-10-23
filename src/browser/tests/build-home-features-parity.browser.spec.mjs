import { test, expect } from '@playwright/test'
import { openParityPair, expectDesignParity } from '../support/design-parity.mjs'
for (const feature of ['pag', 'khala']) for (const width of [1440, 390]) test(`feature header ${feature} ${width}`, async ({ browser }) => {
  test.setTimeout(120000)
  const pair = await openParityPair(browser, { viewport: { width, height: 900 }, theme: 'dark', palette: 'gruvbox' }, { dataset: 'live', query: `feature=${feature}`, motion: true })
  try {
    for (const page of [pair.design, pair.product]) await page.addStyleTag({ content: 'html { overflow-y: scroll !important }' })
    await expect(pair.product.locator('.bd-fh')).toBeVisible()
    const html = page => page.locator('#bd-fh').evaluate(el => el.innerHTML)
    expect(await html(pair.product)).toBe(await html(pair.design))
    await expectDesignParity(pair, { name: `feature-${feature}-${width}`, region: '#bd-fh' })
    await pair.product.locator('[data-m="compact"]').click()
    await pair.design.locator('[data-m="compact"]').click()
    await pair.product.clock.runFor(400); await pair.design.clock.runFor(400)
    for (const page of [pair.design, pair.product]) await page.clock.setSystemTime(1791408000000)
    expect(await html(pair.product)).toBe(await html(pair.design))
    await expectDesignParity(pair, { name: `feature-compact-${feature}-${width}`, region: '#bd-fh' })
  } finally { await pair.close() }
})
