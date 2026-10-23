import { test, expect } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { dashboardCredentials } from './support/layout-worker.mjs'
test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', viewport: { width: 1440, height: 900 } })
test.beforeEach(async ({ page }) => {
  const root = test.info().project.metadata.featuresRoot
  if (root) await page.route('**/build-home/*.js', async route => route.fulfill({ contentType: 'text/javascript', body: await readFile(root + '/src/priv/static/build-home/' + new URL(route.request().url()).pathname.split('/').at(-1), 'utf8') }))
})
async function open(page, query = '?feature=pag', dataset = 'live') {
  await page.goto('/build-fixture/' + dataset + query)
  await expect(page.locator('#build-root')).toHaveAttribute('data-build-generation', /\d+/)
  await page.evaluate(async () => {
    window.m = await import('/build-home/state.js'); window.f = await import('/build-home/features.js')
    window.h = await import('/build-home/hook.js'); window.hist = await import('/build-home/history.js')
  })
}
const mode = (p, m) => p.locator(`#bd-fh [data-m="${m}"]`)
async function diff(page, patch) {
  await page.evaluate(patch => {
    const { ctx } = m, feature = { ...ctx.D.features.pag, ...patch }
    h.receive({ v: 1, kind: 'diff', epoch: ctx.proto.epoch, generation: ctx.proto.generation + 1, now: ctx.snap.now, set: { features: { ...ctx.D.features, pag: feature } }, remove: [], upsert: [] })
  }, patch)
}
test('header uses whole-index figures, mode buttons and clear restore the board', async ({ page }) => {
  await open(page)
  const values = await page.evaluate(() => m.ctx.D.features.pag.stats)
  await expect(page.locator('.bd-kv b').nth(0)).toHaveText(`${values.done}/${values.total}`)
  await expect(page.locator('.bd-kv b').nth(1)).toHaveText(`${values.pct}%`)
  await expect(page.locator('.bd-kv b').nth(2)).toContainText(`${values.orig} → ${values.total}`)
  expect(await page.locator('.bd-card.dim').count()).toBeGreaterThan(0)
  await mode(page, 'compact').click()
  await expect(page).toHaveURL(/fmode=compact/)
  await expect(mode(page, 'compact')).toHaveClass('on')
  const counts = await page.evaluate(() => {
    const { ctx } = m, items = ['hist', 'plan', 'nq'].flatMap(k => ctx.L.secs[k].items)
    return { ghosts: items.filter(i => i.ghost).length, unrelated: items.filter(i => !i.ghost && i.t.feature !== 'pag' && !i.t.also.includes('pag')).length }
  })
  expect(counts.unrelated).toBe(0)
  await expect(page.locator('.bd-mk.gap').first()).toBeAttached()
  await page.locator('#bd-fx').click()
  await expect(page.locator('#bd-fh')).toBeEmpty()
  await expect(page.locator('.bd-card.dim, .bd-card.feat-on, .bd-card.also, .bd-card.ghost')).toHaveCount(0)
  await expect(page).not.toHaveURL(/feature=/)
})
test('unknown stats, baseline, missing stats and labels update through live diffs', async ({ page }) => {
  await open(page)
  const stats = await page.evaluate(() => m.ctx.D.features.pag.stats)
  await diff(page, { label: '<b>renamed</b>', epics: ['missing'], stats: { ...stats, done: null, done_min: 5, pct: null, pct_min: 41, reasons: ['progress', 'status'], baseline: false } })
  await expect(page.locator('.bd-fh-name')).toHaveText('<b>renamed</b>')
  await expect(page.locator('.bd-fh-name b, .bd-chip svg')).toHaveCount(0)
  await expect(page.locator('.bd-kv b').nth(0)).toHaveText(`—/${stats.total}`)
  await expect(page.locator('.bd-kv b').nth(1)).toHaveText('—')
  await expect(page.locator('.bd-kv b').nth(1)).toHaveAttribute('title', 'at least 41% weighted · unknown: progress, status')
  await expect(page.locator('.bd-kv b').nth(2)).toHaveText(`— → ${stats.total}`)
  await expect(page.locator('.bd-kv em')).toHaveCount(0)
  await diff(page, { stats: null })
  await expect(page.locator('.bd-kv b')).toHaveText(['—', '—', '—'])
  await expect(page.locator('.sp polyline')).toHaveCount(0)
})
for (const slug of ['nope', 'constructor', 'toString']) test(`unknown ${slug} stays inactive in graph, compact and list`, async ({ page }) => {
  const errors = []; page.on('pageerror', e => errors.push(e.message))
  await open(page, `?feature=${slug}&fmode=compact`)
  await expect(page.locator('#bd-fh')).toBeEmpty()
  await expect(page.locator('.bd-card.dim, .bd-card.also, .bd-card.feat-on, .bd-card.ghost, .bd-mk.gap')).toHaveCount(0)
  await page.goto(`/build-fixture/live?feature=${slug}&view=list`)
  await expect(page.locator('.bd-list')).toBeVisible()
  await expect(page.locator('.lr.dim')).toHaveCount(0)
  expect(errors).toEqual([])
})
test('first-paint feature focus loads oldest history, back/forward restores focus', async ({ page }) => {
  await open(page, '?feature=khala')
  await expect(page.locator('.bd-fh-name')).toContainText('Khala')
  await expect.poll(() => page.evaluate(() => m.S.histFrom <= m.ctx.D.features.khala.oldest)).toBe(true)
  expect(await page.evaluate(() => m.ctx.D.hist.filter(t => t.feature === 'khala').length)).toBeGreaterThan(0)
  await page.evaluate(() => { const a = document.createElement('a'); a.id = 'feature-navigation'; a.href = '/build-fixture/live?feature=pag'; a.dataset.phxLink = 'patch'; a.dataset.phxLinkState = 'push'; a.textContent = 'Pagination feature'; document.body.appendChild(a) })
  await page.locator('#feature-navigation').click()
  await expect(page.locator('.bd-fh-name')).toContainText('Events pagination')
  await page.goBack()
  await expect(page.locator('.bd-fh-name')).toContainText('Khala')
})
test('clearing during an in-flight page prevents another feature page', async ({ page }) => {
  await open(page, '')
  await page.evaluate(async () => {
    const { ctx, fx } = m; window.calls = 0; const push = ctx.push;
    ctx.push = (e, p) => e === 'load-earlier' ? (calls++, new Promise(resolve => { window.finish = () => push(e, p).then(resolve) })) : push(e, p)
    fx.setFeature('khala')
  })
  await expect(page.locator('.bd-fh-name')).toContainText('Khala')
  await expect.poll(() => page.evaluate(() => calls)).toBe(1)
  await page.locator('#bd-fx').click()
  await page.evaluate(async () => { await finish() })
  await expect(page.locator('#build-root')).toHaveAttribute('data-bd-paging', 'idle')
  expect(await page.evaluate(() => calls)).toBe(1)
})
test('late feature activation and live dependencies rebuild compact ghosts', async ({ page }) => {
  await open(page, '?feature=late&fmode=compact')
  await expect(page.locator('#bd-fh')).toBeEmpty()
  const ids = await page.evaluate(() => {
    const { ctx } = m, member = ctx.D.plan[0], external = ctx.D.nq.find(t => t.epic !== member.epic)
    const feature = { ...ctx.D.features.pag, key: 'late', label: 'Late feature', oldest: null, epics: [member.epic] }
    h.receive({ v: 1, kind: 'diff', epoch: ctx.proto.epoch, generation: ctx.proto.generation + 1, now: ctx.snap.now,
      set: { features: { ...ctx.D.features, late: feature } }, remove: [], upsert: [{ ...member, feature: 'late', deps: [external.id], dep_states: { [external.id]: 'blocking' } }] })
    m.fx.flushLive()
    return { member: member.id, ghost: external.id, epic: external.epic }
  })
  await expect(page.locator('.bd-fh-name')).toHaveText('Late feature')
  const result = await page.evaluate(ids => {
    const { ctx } = m, ghost = ctx.L.secs.nq.items.find(it => it.t.id === ids.ghost)
    return { ghost: ghost?.ghost, cols: ctx.cols, others: ctx.L.secs.plan.items.filter(it => it.t.id !== ids.member && !it.ghost).length }
  }, ids)
  expect(result.ghost).toBe(true); expect(result.cols).toContain(ids.epic); expect(result.others).toBe(0)
  await page.evaluate(ids => { const { ctx, fx } = m; ctx.vp.scrollTop = ctx.secs.nq.el.offsetTop; fx.update() }, ids)
  await expect(page.locator(`.bd-card[data-id="${ids.ghost}"]`)).toHaveClass(/ghost/)
})
test('compact Gantt and list focus use active membership', async ({ page }) => {
  await open(page, '?feature=pag&fmode=compact&view=gantt')
  const result = await page.evaluate(() => ['hist', 'plan', 'nq'].flatMap(k => m.ctx.L.secs[k].items).filter(i => !i.ghost && i.t.feature !== 'pag' && !i.t.also.includes('pag')).length)
  expect(result).toBe(0)
  await page.goto('/build-fixture/live?feature=pag&view=list')
  await expect(page.locator('.lr.dim').first()).toBeVisible()
  const mismatch = await page.locator('.lr[data-id]').evaluateAll(async rows => { const { ctx } = await import('/build-home/state.js'); return rows.filter(el => {
    const t = ctx.D.byId[el.dataset.id]; return el.classList.contains('dim') === (t.feature === 'pag' || t.also.includes('pag'))
  }).length })
  expect(mismatch).toBe(0)
})
