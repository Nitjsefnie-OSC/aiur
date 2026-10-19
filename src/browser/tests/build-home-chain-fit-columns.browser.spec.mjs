import { test, expect } from '@playwright/test'
import { open, lock } from './support/build-home-chains.mjs'
import { installFitObserver } from './support/build-home-chains-parity.mjs'
import { dashboardCredentials } from './support/layout-worker.mjs'

test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', viewport: { width: 1440, height: 900 } })
test('Fit waits for deferred columns before resolving its positioned lock', async ({ page }) => {
  await open(page, { dataset: 'live' })
  await page.locator('[data-span="30"]').click()
  await expect(page.locator('#bd-sec-hist .bd-sech')).toContainText('all 248 from ')
  await page.locator('[data-span="1"]').click()
  await lock(page, '597')
  await installFitObserver(page)
  await page.evaluate(() => {
    const later = st.ctx.life.later.bind(st.ctx.life)
    window.releaseColumns = null
    st.ctx.life.later = (key, delay, callback) => {
      if (key !== 'cols') return later(key, delay, callback)
      window.releaseColumns = () => { st.ctx.life.later = later; callback() }
    }
  })
  await page.locator('[data-lt="fit"]').click()
  await expect.poll(() => page.evaluate(() => typeof window.releaseColumns)).toBe('function')
  await page.evaluate(() => { window.fitResolved = false; window.chainParityFit.then(() => { window.fitResolved = true }) })
  await expect.poll(() => page.evaluate(() => st.ctx.snapping || st.ctx.isScrolling())).toBe(false)
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  const pending = await page.evaluate(() => ({ done: window.fitResolved, actual: st.ctx.cols, expected: st.fx.visibleCols() }))
  expect(pending.actual).not.toEqual(pending.expected)
  expect(pending.done).toBe(false)
  await page.evaluate(async () => { window.releaseColumns(); await window.chainParityFit })
  const final = await page.evaluate(() => {
    const el = [...st.ctx.R.values()].find(el => el.dataset.id === '597')
    const root = el.getBoundingClientRect(), content = st.ctx.content.getBoundingClientRect(), tab = st.ctx.content.querySelector('.bd-lt')
    return { actual: st.ctx.cols, expected: st.fx.visibleCols(), lock: st.ctx.lockId,
      x: parseFloat(tab.style.left), right: root.right - content.left - 1 }
  })
  expect(final.actual).toEqual(final.expected)
  expect(final.lock).toBe('597')
  expect(final.x).toBeCloseTo(final.right, 1)
})
