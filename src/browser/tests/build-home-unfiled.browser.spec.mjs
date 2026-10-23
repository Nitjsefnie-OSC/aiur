import { test, expect } from '@playwright/test'
import { dashboardCredentials } from './support/layout-worker.mjs'
test.use({ httpCredentials: dashboardCredentials, viewport: { width: 1440, height: 1000 } })
async function open(page, dataset = 'unfiled', query = '') {
  await page.goto('/build-fixture/' + dataset + query)
  await expect(page.locator('#build-root')).toHaveAttribute('data-build-generation', /\d+/)
  await expect.poll(() => page.evaluate(async () => (await import('/build-home/state.js')).ctx.D?.plan.some(t => t.src?.kind === 'pack'))).toBe(dataset === 'unfiled')
}
const modules = async page => page.evaluate(async () => {
  const {ctx} = await import('/build-home/state.js')
  const t = ctx.D.plan.find(t => t.src?.kind === 'pack')
  ;(await import('/build-home/modal/frame.js')).openModal(t)
  return t
})
test('pack modal keeps its identity, source and inert document link', async ({page}) => {
  await open(page); const t = await modules(page)
  await expect(page.locator('.bm-num')).toHaveText('—'); await expect(page.locator('.bm-num')).toHaveAttribute('title', 'Not filed yet')
  await expect(page.locator('.bm-st')).toHaveText('Planned · not filed')
  await expect(page.locator('.bm-src')).toHaveText('docs/build-plan.md · wave ' + t.src.wave + ' · not filed yet')
  await expect(page.locator('.bm-facts > div').first().locator('b')).toHaveText('—')
  const link = page.locator('[data-a="none"]'); await expect(link).toHaveAttribute('aria-disabled','true')
  await expect.poll(() => new URL(page.url()).searchParams.get('ticket')).toBe(t.id)
  const url = page.url(); await link.click({force:true}); expect(page.url()).toBe(url)
  await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {configurable:true,value:{writeText:async text => {window.packCopied = text}}}))
  await page.locator('[data-a="link"]').click()
  await expect.poll(() => page.evaluate(() => window.packCopied)).toBe(url)
  await expect(page.locator('#tk-modal')).not.toContainText(/#null|Qnull|undefined|NaN/)
  await page.reload(); await expect(page.locator('.bm-num')).toHaveText('—')
})
test('list shares explicit unfiled labels without nulls', async ({page}) => {
  await open(page, 'unfiled', '?view=list')
  const rows = page.locator('.lr[data-id^="pack:"]'); await expect(rows.first().locator('.c-st .lst')).toHaveText('Not filed')
  await expect(rows.first().locator('.c-st .lst')).toHaveClass(/st-open/)
  await expect(rows.first()).not.toContainText(/null|undefined|NaN/)
  await page.evaluate(async () => {
    const {ctx} = await import('/build-home/state.js'); const t = ctx.D.plan.find(t => t.src?.kind === 'pack')
    ;(await import('/build-home/modal/frame.js')).openModal({...t, title:'<img src=x onerror=alert(1)>'})
  })
  await expect(page.locator('#bm-title')).toContainText('<img src=x onerror=alert(1)>')
  await expect(page.locator('#bm-title img')).toHaveCount(0)
})
test('missing old pack link opens the not-found state', async ({page}) => {
  await open(page, 'unfiled', '?ticket=pack:build-plan/BP-999')
  await expect(page.locator('#bm-title')).toContainText('Ticket not found')
})
test('unavailable packs keep an explicit marker', async ({page}) => {
  await open(page, 'unfiled_unavailable')
  await page.evaluate(async () => {
    const {ctx,fx} = await import('/build-home/state.js')
    const mark = ctx.L.secs.plan.marks.find(m => m.label === 'Planning packs unavailable')
    fx.scrollVP(ctx.secs.plan.el.offsetTop + mark.y - 70, false); fx.update()
  })
  const marker = page.locator('.bd-mk.empty').filter({hasText:'Planning packs unavailable'})
  await expect(marker.locator('b')).toHaveText('Planning packs unavailable')
  await expect(marker.locator('p')).toContainText('1 of 2'); await expect(marker.locator('p')).toContainText('checked')
})
test('filing a row replaces the open modal and URL through its alias', async ({page}) => {
  await open(page); const t = await modules(page)
  await page.evaluate(async t => {
    const {ctx} = await import('/build-home/state.js'), {receive} = await import('/build-home/hook.js')
    const filed = {...t,id:'57',num:57,qpos:3,src:null,was:t.id}
    receive({v:1,kind:'diff',epoch:ctx.proto.epoch,generation:ctx.proto.generation+1,now:ctx.snap.now,remove:[t.id],upsert:[filed],set:{}})
  },t)
  await expect(page.locator('.bm-num')).toHaveText('#57')
  await expect.poll(() => new URL(page.url()).searchParams.get('ticket')).toBe('57')
})
test('board and dependency tree use the same unfiled identity', async ({page}) => {
  await open(page)
  const id = await page.evaluate(async () => {
    const {ctx,fx} = await import('/build-home/state.js')
    const t = ctx.D.plan.find(t => t.src?.kind === 'pack')
    const it = ctx.L.secs.plan.items.find(it => it.t.id === t.id)
    fx.scrollVP(ctx.secs.plan.el.offsetTop + it.y - 70, false); fx.update()
    return t.id
  })
  const card = page.locator('.bd-card[data-id="' + id + '"]')
  await expect(card.locator('.bd-status > span').first()).toHaveText('Not filed')
  await expect(card).not.toContainText(/null|undefined|NaN/)
  await page.evaluate(async id => (await import('/build-home/trees.js')).openTree(id), id)
  const node = page.locator('.bd-tn[data-id="' + id + '"]')
  await expect(node.locator('b')).toHaveText('—'); await expect(node.locator('em')).toContainText('Not filed')
  await expect(node).not.toContainText(/null|undefined|NaN/)
})
