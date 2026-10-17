import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { dashboardCredentials } from './support/layout-worker.mjs'

test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles' })
async function open(page, dataset = 'live', query = '') {
  page.on('pageerror', error => { throw error })
  await page.goto('/build-fixture/' + dataset + query)
  await expect(page.locator('.bd-now-h > b')).toHaveText('Live')
  await page.evaluate(async () => { window.m = await import('/build-home/state.js'); window.band = await import('/build-home/band.js') })
}
async function settle(page) { await page.clock.runFor(1008) }

test('header, permanent noanim cards, minimize URL and preset toggles are wired', async ({ page }) => {
  await open(page)
  await expect(page.locator('.bd-now-st')).toHaveText('3 running3 stuck2 paused')
  await expect(page.locator('#bd-now .bd-card.noanim')).toHaveCount(8)
  await expect(page.locator('.bd-now-eta')).toHaveText('62 to go · ETA —')
  await page.locator('[data-min]').click()
  await expect(page).toHaveURL(/live=min/)
  await expect(page.locator('#bd-now')).toHaveClass(/min/)
  await expect(page.locator('[data-min]')).toHaveAttribute('aria-expanded', 'false')
  await expect(page.locator('#bd-now .bd-card')).toHaveCount(0)
  expect(await page.locator('#bd-now').evaluate(el => el.style.height)).toBe('38px')
  expect(await page.locator('.bd-now-sum button').evaluateAll(els => els.map(el => getComputedStyle(el).flexGrow))).toEqual(['3', '3', '2'])
  await page.locator('.bd-now-sum .bad').click()
  await expect(page).toHaveURL(/astate=error%2Cretries%2Ccommand|astate=error,retries,command/)
  await expect(page).not.toHaveURL(/live=min/)
  await expect(page.locator('.bd-now-st .bad')).toHaveClass('bad on')
  await expect(page.locator('.bd-now-st .bad')).toHaveAttribute('aria-pressed', 'true')
  await expect(page.locator('[data-min]')).toHaveAttribute('aria-expanded', 'true')
  await page.locator('.bd-now-st .bad').click()
  await expect(page).not.toHaveURL(/astate=/)
  await expect(page.locator('.bd-now-st .bad')).toHaveAttribute('aria-pressed', 'false')
})
test('live=min survives initial mount and unknown state gets an accessible count', async ({ page }) => {
  await open(page, 'live', '?live=min')
  await expect(page.locator('#bd-now')).toHaveClass(/min/)
  expect((await page.request.get('/build-control/diff?name=agent-state-null')).ok()).toBe(true)
  await expect(page.locator('.bd-now-sum')).toHaveAttribute('aria-label', '2 running, 3 stuck, 2 paused, 1 state unknown')
})
test('empty fleet is 86px, unavailable source has separate copy and no presets', async ({ page }) => {
  await open(page, 'now0')
  await expect(page.locator('.bd-now-empty')).toHaveText('No agents are working right now.')
  expect(await page.locator('#bd-now').evaluate(el => el.style.height)).toBe('86px')
  expect((await page.request.get('/build-control/diff?name=agents-unavailable')).ok()).toBe(true)
  await expect(page.locator('.bd-now-empty')).toHaveText('Agent states unavailable')
  await expect(page.locator('.bd-now-st button, .bd-now-sum')).toHaveCount(0)
})
test('clock ticks on payload minute boundaries without new diffs and preserves cached timestamps', async ({ page }) => {
  await page.clock.install(); await open(page)
  await expect(page.locator('.bd-now-h time')).toHaveText('14:20')
  await page.clock.runFor(59000)
  await expect(page.locator('.bd-now-h time')).toHaveText('14:20')
  await page.clock.runFor(1000)
  await expect(page.locator('.bd-now-h time')).toHaveText('14:21')
  await open(page, 'offline')
  await expect(page.locator('.bd-now-h time')).toHaveText('cached 14:14')
  await page.clock.runFor(60000)
  await expect(page.locator('.bd-now-h time')).toHaveText('cached 14:14')
})
test('scrolling clears unlocked hover, disables card pointers and settles; reduced motion still snaps', async ({ page }) => {
  await page.clock.install(); await open(page); await settle(page)
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.evaluate(() => {
    window.hoverCalls = []; m.ctx.hoverId = m.ctx.D.now[0].id; m.fx.setHover = id => hoverCalls.push(id)
    m.ctx.vp.scrollTop -= 20
  })
  await page.clock.runFor(16)
  await expect(page.locator('#bd-content')).toHaveClass(/scrolling/)
  expect(await page.evaluate(() => ({ scrolling: m.ctx.isScrolling(), calls: hoverCalls, pointers: getComputedStyle(document.querySelector('#bd-now .bd-card')).pointerEvents }))).toEqual({ scrolling: true, calls: [null], pointers: 'none' })
  await settle(page)
  await expect(page.locator('#bd-content')).not.toHaveClass(/scrolling/)
  expect(await page.evaluate(() => m.ctx.isScrolling())).toBe(false)
  expect(await page.evaluate(() => Math.abs(m.ctx.vp.scrollTop - (m.ctx.secs.hist.el.offsetTop + m.ctx.L.secs.hist.h - 46)))).toBeLessThanOrEqual(1)
})
test('jump uses 420ms cubic easing, clamps and cancels previous animations', async ({ page }) => {
  await page.clock.install(); await open(page); await settle(page)
  await page.evaluate(() => {
    // Tall viewport constraint disables guard so the curve is measured without a second snap.
    m.ctx.vp.style.height = '200px'; m.S.ready = false
    m.fx.scrollVP(300, false); window.start = performance.now(); m.fx.scrollVP(1300, true);
    const sample = at => { window.lastFrame = at; requestAnimationFrame(sample) }; requestAnimationFrame(sample)
  })
  await page.clock.runFor(160)
  const value = await page.evaluate(() => ({ st: m.ctx.vp.scrollTop, elapsed: lastFrame - start }))
  expect(Math.abs(value.st - (300 + 1000 * (1 - (1 - value.elapsed / 420) ** 3)))).toBeLessThanOrEqual(1)
  await page.evaluate(() => m.fx.scrollVP(100, false)); await settle(page)
  expect(await page.evaluate(() => m.ctx.vp.scrollTop)).toBe(100)
  await page.evaluate(() => m.fx.scrollVP(-100, false))
  expect(await page.evaluate(() => m.ctx.vp.scrollTop)).toBe(0)
  await page.evaluate(() => { m.S.view = 'list'; m.fx.jumpNow(true) })
  expect(await page.evaluate(() => m.ctx.vp.scrollTop)).toBe(0)
})
test('tall fleet, paging and scrollbar drag suppress snapping', async ({ page }) => {
  await page.clock.install(); await open(page, 'now24'); await settle(page)
  expect(await page.locator('#bd-now .bd-card')).toHaveCount(24)
  const before = await page.evaluate(() => m.ctx.vp.scrollTop)
  await page.evaluate(() => m.ctx.vp.scrollTop -= 100); await settle(page)
  expect(await page.evaluate(() => m.ctx.vp.scrollTop)).toBe(before - 100)
  await open(page); await settle(page)
  for (const mode of ['paging', 'drag']) {
    const result = await page.evaluate(async mode => {
      if (mode === 'paging') (await import('/build-home/history.js')).H.state = 'loading'
      else document.querySelector('#bd-sb').classList.add('drag')
      m.ctx.vp.scrollTop -= 100; return m.ctx.vp.scrollTop
    }, mode)
    await settle(page)
    expect(await page.evaluate(() => m.ctx.vp.scrollTop)).toBe(result)
  }
})
test('destroy cancels band frames, settle locks and clock ticks; remount resets scrolling', async ({ page }) => {
  await page.clock.install(); await open(page); await settle(page)
  const initial = await page.evaluate(() => {
    m.fx.scrollVP(300, true); m.fx.markScrolling()
    const vp = m.ctx.vp, time = m.ctx.bandEl.querySelector('time')
    window.old = { vp, time, st: vp.scrollTop, text: time.textContent }
    document.querySelector('a[href="/commands"]').click(); return old.text
  })
  await expect(page.locator('#bd-vp')).toHaveCount(0)
  await page.clock.runFor(65000)
  expect(await page.evaluate(() => ({ st: old.vp.scrollTop, text: old.time.textContent, initial: old.st }))).toEqual({ st: await page.evaluate(() => old.st), text: initial, initial: await page.evaluate(() => old.st) })
  await open(page); await expect(page.locator('.bd-now-h > b')).toHaveText('Live')
  await settle(page)
  expect(await page.evaluate(async () => (await import('/build-home/state.js')).ctx.isScrolling())).toBe(false)
})
for (const theme of ['dark', 'light']) test(`normal and minimized band pass axe: ${theme}`, async ({ page }) => {
  await page.emulateMedia({ colorScheme: theme }); await open(page)
  for (const min of [false, true]) {
    if (min) await page.locator('[data-min]').click()
    const results = await new AxeBuilder({ page }).include('#bd-now').withRules(['nested-interactive', 'button-name', 'aria-allowed-attr', 'aria-valid-attr-value']).analyze()
    expect(results.violations).toEqual([])
    if (min) await expect(page.locator('.bd-now-sum')).toHaveAttribute('role', 'group')
  }
})

test('keyboard minimize, expand and preset expansion retain focus', async ({ page }) => {
  await open(page)
  await page.locator('[data-min]').focus(); await page.keyboard.press('Enter')
  await expect(page.locator('[data-min]')).toBeFocused()
  await page.keyboard.press('Space')
  await expect(page.locator('[data-min]')).toBeFocused()
  await expect(page.locator('[data-min]')).toHaveAttribute('aria-expanded', 'true')
  await page.keyboard.press('Enter')
  await page.locator('.bd-now-sum .bad').focus(); await page.keyboard.press('Enter')
  await expect(page.locator('.bd-now-st .bad')).toBeFocused()
})

test('Live button floating state and click use the actual band geometry', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1100 })
  await page.clock.install(); await open(page, 'newrepo'); await settle(page)
  const floating = await page.evaluate(() => {
    m.ctx.vp.scrollTop = 0; m.fx.update()
    const r = m.ctx.bandEl.getBoundingClientRect(), v = m.ctx.vp.getBoundingClientRect()
    return { top: r.top - v.top, bottom: v.bottom - r.bottom, at: document.querySelector('#bd-nowbtn').classList.contains('at') }
  })
  expect(floating.top).toBeGreaterThan(76); expect(floating.bottom).toBeGreaterThan(30); expect(floating.at).toBe(true)
  await page.locator('#bd-nowbtn').evaluate(el => el.click()); await settle(page)
  const error = await page.evaluate(() => Math.abs(m.ctx.vp.scrollTop - (m.ctx.secs.hist.el.offsetTop + m.ctx.L.secs.hist.h - 46)))
  expect(error).toBeLessThanOrEqual(1)
  await expect(page.locator('#bd-nowbtn')).not.toHaveClass(/at/)
})
