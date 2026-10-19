import { expect, test } from '@playwright/test'
import { openFixture } from './support/browser-helpers.mjs'
import { dashboardCredentials } from './support/layout-worker.mjs'

test('bottom navigation keeps every link inside the bar at 200% text zoom', async ({ browser }) => {
  const context = await browser.newContext({
    viewport: { width: 720, height: 900 },
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
    await expect.poll(() => navigation.evaluate(node => node.scrollWidth <= node.clientWidth)).toBe(true)

    const bounds = await navigation.evaluate(node => {
      const nav = node.getBoundingClientRect()
      return Array.from(node.querySelectorAll('a.snav'), link => {
        const rect = link.getBoundingClientRect()
        return { left: rect.left, right: rect.right, navLeft: nav.left, navRight: nav.right }
      })
    })
    expect(bounds.every(link => link.left >= link.navLeft && link.right <= link.navRight)).toBe(true)
    for (const link of await navigation.locator('a.snav').all()) await expect(link).toBeVisible()
  } finally {
    await context.close()
  }
})
