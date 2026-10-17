import { fileURLToPath } from 'node:url'
import { test, expect } from '@playwright/test'
import { dashboardCredentials } from './support/layout-worker.mjs'

test.use({ colorScheme: 'light', httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', viewport: { width: 1440, height: 900 } })
async function open(page, dataset = 'live') {
  await page.route(/\/build-home\/[\w-]+\.js$/, route => route.fulfill({ path: fileURLToPath(new URL('../../priv/static/build-home/' + new URL(route.request().url()).pathname.split('/').at(-1), import.meta.url)), contentType: 'text/javascript' }))
  await page.clock.setFixedTime(1791408000000)
  await page.goto('/build-fixture/' + dataset)
  await expect(page.locator('#bd-content')).toHaveCount(1)
  await page.evaluate(async () => { window.st = await import('/build-home/state.js') })
  await expect.poll(() => page.evaluate(() => !!st.ctx.D)).toBe(true)
}
const navigate = (page, path) => page.evaluate(path => window.liveSocket.main.pushLinkPatch(new Event('click'), path, null), path)

// B2/B11: the oracle uses payload rows and visible cards, independently of the renderer.
for (const dataset of ['live', 'dense']) test(`windowed edge count follows visible endpoint pairs: ${dataset}`, async ({ page }) => {
  await open(page, dataset)
  const samples = await page.evaluate(() => {
    const { ctx, fx } = st, samples = []
    for (const sec of ['hist', 'plan', 'nq']) for (const offset of [1000, 0]) {
      ctx.vp.scrollTop = ctx.secs[sec].el.offsetTop + offset; fx.update(); fx.drawEdges(true)
      const visible = new Set([...ctx.R.values(), ...ctx.L.band.items.map(it => it.el)].filter(el => el.style.opacity !== '0').map(el => el.dataset.id))
      const expected = [...visible].flatMap(id => (ctx.D.byId[id]?.deps ?? []).filter(did => visible.has(did)).map(did => [did, id]))
      samples.push({ expected: expected.length, actual: ctx.svg.querySelectorAll('.bd-eh').length,
        missing: [...visible].flatMap(id => (ctx.D.byId[id]?.deps ?? []).filter(did => !visible.has(did))).length,
        rendered: visible.size, total: Object.keys(ctx.D.byId).length })
    }
    return samples
  })
  for (const s of samples) expect(s.actual).toBe(s.expected)
  expect(samples.some(s => s.missing > 0)).toBe(true)
  expect(samples.some(s => s.actual > 0)).toBe(true)
  expect(samples.every(s => s.rendered < s.total)).toBe(true)
})

test('B4/B12 odd edges draw cycles, failed and unknown without errors', async ({ page }, info) => {
  const errors = []; page.on('pageerror', e => errors.push(e.message))
  await open(page, 'odd-edges')
  const edges = await page.evaluate(() => {
    const { ctx, fx } = st, result = {}
    for (const sec of ['hist', 'nq']) {
      ctx.vp.scrollTop = ctx.secs[sec].el.offsetTop; fx.update(); fx.drawEdges(true)
      for (const hit of ctx.svg.querySelectorAll('.bd-eh')) result[hit.dataset.e] = hit.nextElementSibling.getAttribute('class').trim()
    }
    return result
  })
  expect(edges).toMatchObject({ 12: 'bd-e bad', 19: 'bd-e', 1: 'bd-e bl', 2: 'bd-e bl', 3: 'bd-e bl', 4: 'bd-e bl', 5: 'bd-e bl' })
  info.annotations.push({ type: 'pending-sign-off', description: 'S-24 odd edges / C4-T05' })
  await expect(page.locator('#bd-edges')).toHaveScreenshot('odd-edges.png')
  expect(errors).toEqual([])
})

test('B8 destroy cancels pending draws and disconnected content is untouched', async ({ page }) => {
  await open(page)
  await page.evaluate(() => {
    window.oldSVG = st.ctx.svg; window.mutations = 0
    window.edgeObserver = new MutationObserver(() => { if (!oldSVG.isConnected) mutations++ })
    edgeObserver.observe(oldSVG, { attributes: true, childList: true, subtree: true })
    st.fx.drawEdgesSoon(420)
  })
  await page.waitForTimeout(50)
  await navigate(page, '/commands')
  await expect(page.locator('#bd-content')).toHaveCount(0)
  await page.waitForTimeout(600)
  expect(await page.evaluate(() => mutations)).toBe(0)
  // Also exercise the defensive guard independently of lifecycle cancellation.
  expect(await page.evaluate(() => {
    edgeObserver.takeRecords()
    st.fx.drawEdges(true)
    return edgeObserver.takeRecords().length === 0
  })).toBe(true)
})

test('B8b navigating back during a draw loop renders a fresh mount', async ({ page }) => {
  await open(page)
  // Keep the deadline alive across navigation even when the shared host is busy.
  const count = await page.evaluate(() => { st.fx.drawEdges(true); st.fx.drawEdgesSoon(60_000); return st.ctx.svg.querySelectorAll('.bd-eh').length })
  expect(count).toBeGreaterThan(0)
  await navigate(page, '/commands')
  await expect(page.locator('#bd-content')).toHaveCount(0)
  await navigate(page, '/build')
  await expect.poll(() => page.locator('#bd-edges .bd-eh').count()).toBe(count)
})

test('B3 an unloaded blocker has no edge until earlier history is loaded', async ({ page }) => {
  await open(page)
  const full = await import('../../test/fixtures/build_home/live.json', { with: { type: 'json' } })
  const result = await page.evaluate(async snapshot => {
    const { ctx, fx, S } = st, history = await import('/build-home/history.js')
    const rows = Object.fromEntries(snapshot.sections.hist.map(row => [row.id, row]))
    const child = ctx.D.hist.find(row => row.deps.some(id => rows[id] && !ctx.D.byId[id]))
    if (!child) throw new Error('fixture needs a dependency in an unloaded history day')
    const parent = rows[child.deps.find(id => rows[id] && !ctx.D.byId[id])]
    const read = () => [...ctx.svg.querySelectorAll(`.bd-eh[data-e="${child.id}"]`)].length
    ctx.vp.scrollTop = ctx.secs.hist.el.offsetTop; fx.update(); fx.drawEdges(true)
    const before = read()
    await history.ensureFrom(parent.end)
    S.span = 7; fx.relayout()
    const item = ctx.L.secs.hist.items.find(it => it.t.id === child.id)
    ctx.vp.scrollTop = ctx.secs.hist.el.offsetTop + item.y; fx.update(); fx.drawEdges(true)
    return { before, loaded: !!ctx.D.byId[parent.id], parentRendered: [...ctx.R.values()].some(el => el.dataset.id === parent.id), after: read() }
  }, full.default)
  expect(result).toEqual({ before: 0, loaded: true, parentRendered: true, after: 1 })
})
