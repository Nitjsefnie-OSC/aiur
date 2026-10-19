import { expect, test } from '@playwright/test'
import { openFixture } from './support/browser-helpers.mjs'
import { dashboardCredentials } from './support/layout-worker.mjs'

for (const width of [390, 720]) {
  test(`bottom navigation keeps every link reachable without page overflow at 200% text zoom (${width}px)`, async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width, height: 900 },
      deviceScaleFactor: 2,
      reducedMotion: 'reduce',
      httpCredentials: dashboardCredentials
    })
    const page = await context.newPage()

    try {
      await openFixture(page)
      await page.goto('/')
      await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })

      const navigation = page.locator('.sidenav-nav')
      await expect(navigation.locator('a.snav')).toHaveCount(6)
      await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true)
      await expect.poll(() => navigation.evaluate(node => getComputedStyle(node).overflowX)).toBe('auto')

      for (const link of await navigation.locator('a.snav').all()) {
        await link.evaluate(node => node.scrollIntoView({ block: 'nearest', inline: 'center' }))
        const bounds = await link.evaluate(node => {
          const nav = node.closest('.sidenav-nav').getBoundingClientRect()
          const rect = node.getBoundingClientRect()
          return { left: rect.left, right: rect.right, navLeft: nav.left, navRight: nav.right }
        })
        expect(bounds.left).toBeGreaterThanOrEqual(bounds.navLeft - 1)
        expect(bounds.right).toBeLessThanOrEqual(bounds.navRight + 1)
        const label = link.locator('.snav-label')
        expect(await label.evaluate(node => node.scrollWidth <= node.clientWidth)).toBe(true)
        await expect(link).toBeVisible()
      }
    } finally {
      await context.close()
    }
  })
}
