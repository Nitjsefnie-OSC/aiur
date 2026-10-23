import { test, expect } from '@playwright/test'
import { dashboardCredentials } from './support/layout-worker.mjs'
test.use({ httpCredentials: dashboardCredentials, viewport: { width: 1440, height: 1000 } })
async function open(page, dataset = 'unfiled', query = '') {
  await page.goto('/build-fixture/' + dataset + query)
  await expect(page.locator('#bd-content')).toHaveCount(1)
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
  const url = page.url(); await link.click(); expect(page.url()).toBe(url)
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
  const marker = page.locator('.bd-mk.empty').filter({hasText:'Planning packs unavailable'})
  await expect(marker.locator('b')).toHaveText('Planning packs unavailable')
  await expect(marker.locator('p')).toContainText('1 of 2'); await expect(marker.locator('p')).toContainText('checked')
})
test('filing a row replaces the open modal and URL through its alias', async ({page}) => {
  await open(page); const t = await modules(page)
  await page.evaluate(async t => {
    const {ctx} = await import('/build-home/state.js'); const filed = {...t,id:'57',num:57,qpos:3,src:null,was:t.id}
    delete ctx.D.byId[t.id]; ctx.D.byId[filed.id] = filed
    ;(await import('/build-home/modal/frame.js')).modalSync({remove:[t.id],upsert:[filed]})
  },t)
  await expect(page.locator('.bm-num')).toHaveText('#57')
  await expect.poll(() => new URL(page.url()).searchParams.get('ticket')).toBe('57')
})
