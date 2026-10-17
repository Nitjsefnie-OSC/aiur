import { fileURLToPath } from 'node:url'
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { dashboardCredentials } from './support/layout-worker.mjs'

test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', viewport: { width: 1440, height: 900 } })
const card = (page, id) => page.locator(`.bd-card[data-id="${id}"]`).first()
const tree = page => page.locator('#bd-tree')
const tray = page => page.locator('.bd-lt')

async function open(page, { trees = true, dataset = 'chains', modal = false } = {}) {
  if (modal) await page.addInitScript(() => {
    // Register before the hook: a bubble-only tree handler would close both layers.
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') document.querySelector('#tk-backdrop.show')?.remove()
    })
  })
  await page.route(/\/build-home\/[\w-]+\.js$/, route => route.fulfill({
    path: fileURLToPath(new URL('../../priv/static/build-home/' + new URL(route.request().url()).pathname.split('/').at(-1), import.meta.url)),
    contentType: 'text/javascript',
  }))
  await page.goto('/build-fixture/' + dataset)
  await expect(page.locator('#build-root')).toHaveAttribute('data-bd-trees', 'ready')
  await page.evaluate(async () => { window.st = await import('/build-home/state.js') })
  if (trees) {
    // The fixture's HTTP forwarding drops queries; use the actual LiveView URL path.
    await page.evaluate(() => window.liveSocket.main.pushLinkPatch(new Event('click'), '/build?trees=1', null))
    await expect.poll(() => page.evaluate(() => st.S.trees)).toBe(true)
  }
  await expect.poll(() => page.evaluate(() => !!st.ctx.D?.byId)).toBe(true)
  if (modal) await page.evaluate(() => {
    st.fx.openModal = row => {
      window.openedTicket = row.id
      const backdrop = document.createElement('div')
      backdrop.id = 'tk-backdrop'; backdrop.className = 'show'
      document.body.append(backdrop)
    }
  })
}
async function reveal(page, id) {
  await page.evaluate(id => {
    const { ctx } = st
    for (const sx of ['hist', 'plan', 'nq']) {
      const it = ctx.L.secs[sx].items.find(it => it.t.id === id)
      if (it) ctx.vp.scrollTop = ctx.secs[sx].el.offsetTop + it.y - 150
    }
    st.fx.update()
  }, String(id))
  await expect(card(page, id)).toBeVisible()
  await page.waitForTimeout(450) // Scroll hover suppression must expire before a real pointer enters.
}
async function lock(page, id) {
  await reveal(page, id)
  await card(page, id).hover()
  await expect(tray(page)).toHaveClass(/show/)
  await expect.poll(() => page.evaluate(() => st.ctx.hoverId)).toBe(String(id))
  await page.waitForTimeout(230) // Let the tab finish moving before aiming at its lock button.
  await page.locator('[data-lt="lock"]').click()
  await expect(page.locator('[data-lt="lock"]')).toHaveAttribute('aria-pressed', 'true')
  await expect.poll(() => page.evaluate(() => st.ctx.lockId)).toBe(String(id))
}
async function whole(page, id) {
  await lock(page, id)
  await page.locator('[data-lt="tree"]').click()
  await expect(tree(page)).toBeVisible()
}
async function diff(page, name) {
  const response = await page.request.get('/build-control/diff?name=' + name)
  expect(response.status(), await response.text()).toBe(200)
}
async function arrowPoint(page) {
  return page.evaluate(() => {
    for (const path of document.querySelectorAll('.bd-eh')) {
      const matrix = path.getScreenCTM(), len = path.getTotalLength()
      for (let i = 1; i < 50; i++) {
        const p = path.getPointAtLength(len * i / 50)
        const x = matrix.a * p.x + matrix.e, y = matrix.d * p.y + matrix.f
        if (x > 0 && x < innerWidth && y > 0 && y < innerHeight && document.elementFromPoint(x, y) === path) return { x, y, id: path.dataset.e }
      }
    }
    return null
  })
}

test('B1 hover requires trees=1; arrow click still locks without it', async ({ page }) => {
  await open(page, { trees: false })
  await reveal(page, '9012'); await card(page, '9012').hover()
  await expect(page.locator('.bd-content')).not.toHaveClass(/hovering/)
  await expect(page.locator('.bd-card.hl')).toHaveCount(0)
  await expect(tray(page)).not.toHaveClass(/show/)
  const point = await arrowPoint(page)
  expect(point).not.toBeNull()
  await page.mouse.click(point.x, point.y)
  await expect.poll(() => page.evaluate(() => st.ctx.lockId)).toBe(point.id)
})

test('B2 hover clears after 280ms on empty content and 200ms on leaving', async ({ page }) => {
  await open(page); await reveal(page, '9012')
  await page.clock.install(); await page.clock.pauseAt(new Date())
  await card(page, '9012').hover()
  await expect(page.locator('.bd-content')).toHaveClass(/hovering/)
  // Dispatch on the real listener target; fixed clock makes the two boundaries exact.
  await page.locator('#bd-content').dispatchEvent('pointerover', { pointerType: 'mouse' })
  await page.clock.runFor(250)
  await expect(page.locator('.bd-content')).toHaveClass(/hovering/)
  await page.clock.runFor(70)
  await expect(page.locator('.bd-content')).not.toHaveClass(/hovering/)
  await card(page, '9012').dispatchEvent('pointerover', { pointerType: 'mouse' })
  await page.locator('#bd-content').dispatchEvent('mouseleave')
  await page.clock.runFor(190)
  await expect(page.locator('.bd-content')).toHaveClass(/hovering/)
  await page.clock.runFor(30)
  await expect(page.locator('.bd-content')).not.toHaveClass(/hovering/)
})

test('B3 cycle overlay has three actual levels and restores focus', async ({ page }) => {
  await open(page); await whole(page, '3')
  await expect(tree(page).locator('.bd-tree-h')).toContainText('#3 · 3 tickets · 3 levels')
  await expect(tree(page).locator('.bd-tn')).toHaveCount(3)
  await expect(page.locator('#bd-tree-x')).toBeFocused()
  await page.screenshot({ path: test.info().outputPath('chain-tree-desktop.png') })
  await page.keyboard.press('Escape')
  await expect(tree(page)).toBeHidden()
  await expect(page.locator('[data-lt="tree"]')).toBeFocused()
  await expect(tray(page)).toHaveClass(/locked/)
  await page.keyboard.press('Escape')
  await expect(tray(page)).not.toHaveClass(/locked/)
})

test('B4 unloaded members and unknown dependency counts are explicit', async ({ page }) => {
  await open(page); await whole(page, '9012')
  await expect(tree(page).locator('.bd-tree-h')).toContainText('4 not on the board')
  await page.keyboard.press('Escape'); await page.keyboard.press('Escape')
  await whole(page, '9024')
  await expect(tree(page).locator('.bd-tree-h')).toContainText('links not yet known')
})

test('B5 unknown node text and hostile titles stay honest and escaped', async ({ page }) => {
  await open(page); await whole(page, '9021')
  await expect(tree(page).locator('.bd-tn[data-id="9020"] em')).toHaveText('State unknown · —')
  await expect(tree(page).locator('.bd-tn[data-id="9020"]')).not.toHaveClass(/ag-/)
  await expect(tree(page).locator('.bd-tn[data-id="9021"] em')).toContainText('Q?')
  await expect(tree(page).locator('.bd-tn[data-id="9022"] em')).toContainText('W?')
  await expect(tree(page).locator('.bd-tn[data-id="9023"] em')).toHaveText('Not planned')
  await expect(tree(page).locator('img, script')).toHaveCount(0)
  expect(await page.evaluate(() => window.__xss)).toBeUndefined()
  await expect(tree(page)).not.toContainText(/null%|Qnull|Wnull|#null|0%/)
  const title = await page.evaluate(() => st.ctx.D.byId['9021'].title)
  await expect(tree(page).locator('.bd-tn[data-id="9021"] .bd-tn1 > span')).toHaveText(title)
})

test('B6 Fit pages history, updates zoom and restores its lock', async ({ page }) => {
  await open(page); await lock(page, '9012')
  await page.evaluate(() => {
    const push = st.ctx.push; window.earlierCalls = []; st.S.histFrom = new Date(st.ctx.snap.now).setHours(0, 0, 0, 0)
    st.ctx.push = (event, params) => { if (event === 'load-earlier') earlierCalls.push(params); return push(event, params) }
  })
  await page.locator('[data-lt="fit"]').click()
  await expect.poll(() => page.evaluate(() => earlierCalls.length)).toBeGreaterThan(0)
  await expect(page.locator('#build-root')).toHaveAttribute('data-bd-paging', 'idle')
  await expect.poll(() => page.evaluate(() => st.ctx.lockId)).toBe('9012')
  // Only loaded timestamps can guide Fit; unloaded blocker dates are intentionally unknown.
  await expect(card(page, '9005')).toBeVisible()
  const oldest = await card(page, '9005').boundingBox(), vp = await page.locator('#bd-vp').boundingBox()
  expect(oldest.y).toBeGreaterThanOrEqual(vp.y)
  expect(oldest.y + oldest.height).toBeLessThanOrEqual(vp.y + vp.height)
  const span = await page.evaluate(() => st.S.span)
  expect(span).toBeGreaterThan(1)
  await expect(page).toHaveURL(new RegExp('span=' + span))
  await expect(page.locator('.bd-zv')).toHaveText(Math.round(100 / span) + '%')
})

for (const mode of ['cancel', 'failure']) test(`B6 Fit ${mode} does not reclaim a released lock`, async ({ page }) => {
  await open(page); await lock(page, '9012')
  await page.evaluate(() => { st.S.histFrom = new Date(st.ctx.snap.now).setHours(0, 0, 0, 0) })
  await page.request.get('/build-control/earlier?' + (mode === 'cancel' ? 'delay=500' : 'fail=1'))
  await page.locator('[data-lt="fit"]').click()
  if (mode === 'cancel') {
    await expect(page.locator('#build-root')).toHaveAttribute('data-bd-paging', 'loading')
    await page.keyboard.press('Escape')
  } else await expect(page.locator('#build-root')).toHaveAttribute('data-bd-paging', 'error')
  await page.waitForTimeout(700)
  if (mode === 'cancel') expect(await page.evaluate(() => st.ctx.lockId)).toBeNull()
  else await expect(page.locator('#bd-sec-hist')).toContainText('earlier days could not load')
})

test('B7 live dependencies refresh highlight, tab position and open overlay', async ({ page }) => {
  await open(page); await whole(page, '9012')
  await diff(page, 'chain-add-dep')
  await expect(tree(page).locator('.bd-tn[data-id="615"]')).toHaveCount(1)
  await page.keyboard.press('Escape')
  await reveal(page, '615')
  await expect(card(page, '615')).toHaveClass(/hl/)
  await reveal(page, '9012')
  const positions = await page.evaluate(() => {
    const el = [...st.ctx.R.values()].find(el => el.dataset.id === '9012')
    const r = el.getBoundingClientRect(), c = st.ctx.content.getBoundingClientRect(), tab = st.ctx.content.querySelector('.bd-lt')
    return { left: parseFloat(tab.style.left), top: parseFloat(tab.style.top), x: r.right - c.left - 1, y: r.top - c.top + Math.max(0, r.height / 2 - 14) }
  })
  expect(positions.left).toBeCloseTo(positions.x, 1); expect(positions.top).toBeCloseTo(positions.y, 1)
  expect(await page.evaluate(() => st.ctx.lockId)).toBe('9012')
})

test('B8 removed root closes overlay and focuses the board', async ({ page }) => {
  await open(page); await whole(page, '9012')
  await diff(page, 'chain-remove-root')
  await expect(tree(page)).toBeHidden()
  await expect(page.locator('#bd-vp')).toBeFocused()
  expect(await page.evaluate(() => st.ctx.lockId)).toBeNull()
})

test('B9 cards rendered by scrolling receive locked chain classes', async ({ page }) => {
  await open(page, { dataset: 'dense' })
  const id = await page.evaluate(() => [...st.ctx.R.values()].find(el => !el.closest('.bd-now')).dataset.id)
  await lock(page, id)
  const before = await page.locator('.bd-card').evaluateAll(els => els.map(el => el.dataset.id))
  await page.locator('#bd-vp').evaluate(el => { el.scrollTop += 3000 })
  await expect.poll(() => page.locator('.bd-card').evaluateAll((els, before) => els.filter(el => !before.includes(el.dataset.id)).length, before)).toBeGreaterThan(0)
  const classes = await page.locator('.bd-card').evaluateAll((els, id) => els.filter(el => el.dataset.id !== id).map(el => ({ id: el.dataset.id, marked: el.matches('.hl, .hdim') })), id)
  expect(classes.length).toBeGreaterThan(0)
  expect(classes.filter(c => !c.marked)).toEqual([])
})

test.describe('B10 phone touch', () => {
  test.use({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true })
  test('card tap opens the ticket without hover; arrow tap locks and opens tree', async ({ page }) => {
    await open(page, { modal: true }); await reveal(page, '9012')
    await card(page, '9012').tap()
    expect(await page.evaluate(() => window.openedTicket)).toBe('9012')
    await expect(page.locator('.bd-content')).not.toHaveClass(/hovering/)
    await page.keyboard.press('Escape')
    const point = await arrowPoint(page)
    expect(point).not.toBeNull()
    await page.touchscreen.tap(point.x, point.y)
    await expect.poll(() => page.evaluate(() => st.ctx.lockId)).toBe(point.id)
    await page.locator('[data-lt="tree"]').tap()
    await expect(tree(page)).toBeVisible()
    await page.screenshot({ path: test.info().outputPath('chain-tree-phone.png') })
  })
})

test('B11 Escape closes the ticket before the dependency tree', async ({ page }) => {
  await open(page, { modal: true }); await whole(page, '3')
  await tree(page).locator('.bd-tn[data-id="3"]').click()
  await expect(page.locator('#tk-backdrop.show')).toHaveCount(1)
  await page.keyboard.press('Escape')
  await expect(page.locator('#tk-backdrop.show')).toHaveCount(0)
  await expect(tree(page)).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(tree(page)).toBeHidden()
})

test('B12 browser Back disabling trees clears a lock', async ({ page }) => {
  await open(page, { trees: false })
  await page.evaluate(() => window.liveSocket.pushHistoryPatch(new Event('click'), '/build', 'push', null))
  await expect(page).toHaveURL(/\/build$/)
  await page.evaluate(() => window.liveSocket.pushHistoryPatch(new Event('click'), '/build?trees=1', 'push', null))
  await expect.poll(() => page.evaluate(() => st.S.trees)).toBe(true)
  await lock(page, '9012')
  await page.goBack()
  await expect.poll(() => page.evaluate(() => st.S.trees)).toBe(false)
  expect(await page.evaluate(() => st.ctx.lockId)).toBeNull()
  await expect(page.locator('.bd-content')).not.toHaveClass(/hovering/)
})

test('B13 navigation cancels a pending Fit and removes tree document listeners', async ({ page }) => {
  const errors = []; page.on('pageerror', error => errors.push(error.message))
  await open(page); await lock(page, '9012')
  await page.evaluate(() => { st.S.histFrom = new Date(st.ctx.snap.now).setHours(0, 0, 0, 0) })
  await page.request.get('/build-control/earlier?delay=500')
  await page.evaluate(() => {
    window.lateTreeCalls = []; const life = st.ctx.life
    for (const key of ['relayout', 'lockTree', 'unlock', 'closeTree']) {
      const fn = st.fx[key]
      st.fx[key] = (...args) => { if (life.disposed) lateTreeCalls.push(key); return fn(...args) }
    }
  })
  await page.locator('[data-lt="fit"]').click()
  await expect(page.locator('#build-root')).toHaveAttribute('data-bd-paging', 'loading')
  await page.evaluate(() => window.liveSocket.main.pushLinkPatch(new Event('click'), '/commands', null))
  await expect(page.locator('#build-root')).toHaveCount(0)
  await page.keyboard.press('Escape'); await page.locator('body').click({ position: { x: 2, y: 2 } })
  await page.waitForTimeout(700)
  expect(await page.evaluate(() => lateTreeCalls)).toEqual([])
  expect(errors).toEqual([])
})

test('B13 teardown between Fit frames cancels the second frame', async ({ page }) => {
  await open(page); await lock(page, '3')
  const result = await page.evaluate(async () => {
    const life = st.ctx.life, hook = await import('/build-home/hook.js')
    const frame = life.frame.bind(life), calls = []
    // Dispose using the hook's real teardown exactly after Fit's first frame.
    life.frame = (key, fn) => frame(key, () => {
      fn()
      if (key === 'fit-1') hook.createBuildHomeHook().destroyed.call({ buildLife: life })
    })
    const update = st.fx.update
    st.fx.update = (...args) => { if (life.disposed) calls.push('update'); return update(...args) }
    st.ctx.content.querySelector('[data-lt="fit"]').click()
    await new Promise(resolve => setTimeout(resolve, 100))
    return { disposed: life.disposed, calls, lock: st.ctx.lockId }
  })
  expect(result.disposed).toBe(true)
  expect(result.calls).toEqual([])
  expect(result.lock).toBeNull()
})

for (const action of ['lock', 'Escape']) test(`B13 ${action} between Fit frames supersedes the pending root`, async ({ page }) => {
  await open(page); await lock(page, '3')
  const result = await page.evaluate(async action => {
    const life = st.ctx.life, frame = life.frame.bind(life)
    life.frame = (key, fn) => frame(key, () => {
      fn()
      if (key === 'fit-1') {
        if (action === 'lock') st.fx.lockTree('1')
        else document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }))
      }
    })
    st.ctx.content.querySelector('[data-lt="fit"]').click()
    await new Promise(resolve => setTimeout(resolve, 100))
    return st.ctx.lockId
  }, action)
  expect(result).toBe(action === 'lock' ? '1' : null)
})

test('B14 locked board and tree have no axe violations; dialog traps Tab', async ({ page }) => {
  await open(page); await lock(page, '3')
  expect((await new AxeBuilder({ page }).include('#build-root').analyze()).violations).toEqual([])
  await page.locator('[data-lt="tree"]').click()
  await expect(page.getByRole('dialog', { name: 'Dependency tree' })).toBeVisible()
  await expect(page.locator('#bd-tree-x')).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(tree(page).locator('.bd-tn').last()).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(page.locator('#bd-tree-x')).toBeFocused()
  expect((await new AxeBuilder({ page }).include('#bd-tree').analyze()).violations).toEqual([])
})

test.afterEach(async ({ page }) => { await page.request.get('/build-control/earlier') })
