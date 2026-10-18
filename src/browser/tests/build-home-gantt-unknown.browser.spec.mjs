import { test, expect } from '@playwright/test'
import { captureStable, openProduct, parityContextOptions, PARITY_VIEWPORTS, PARITY_THRESHOLD } from '../support/design-parity.mjs'

for (const width of [1440, 390]) for (const theme of ['dark', 'light']) test(`S-5 adopted unknown-value capture: ${width} ${theme}`, async ({ browser }, info) => {
  test.setTimeout(120000)
  const cell = { ...PARITY_VIEWPORTS.find(v => v.viewport.width === width), theme, palette: 'aiur', dataset: 'live' }
  const context = await browser.newContext({ ...parityContextOptions(cell), baseURL: info.project.use.baseURL })
  try {
    const page = await context.newPage(); await openProduct(page, cell, { query: 'view=gantt', motion: true })
    const markers = await page.evaluate(async () => {
      const { ctx, S, fx } = await import('/build-home/state.js'), { receive } = await import('/build-home/hook.js')
      const end = ctx.snap.now
      const hist = { ...ctx.snap.sections.hist[0], id: 's5-start-unknown', start: null, end, title: 'Start unknown' }
      const plan = { ...ctx.snap.sections.plan[0], id: 's5-estimate-unknown', est: null, override: null, wave: 1, title: 'Estimate unknown' }
      S.span = 1; S.ready = false; S.histFrom = end - 86400000
      receive({ ...ctx.snap, kind: 'snapshot', generation: ctx.proto.generation + 1, sections: { hist: [hist], now: [], plan: [plan], nq: [] }, history: { ...ctx.snap.history, from: end - 86400000, more: false, total: 1 } })
      ctx.vp.scrollTop = 0; fx.update()
      return ['s5-start-unknown', 's5-estimate-unknown'].map(id => {
        const el = ctx.R.get((id.includes('start') ? 'hist:' : 'plan:') + id)
        return { id, cls: el.className, title: el.querySelector('.bd-in').title, height: parseFloat(el.style.height) }
      })
    })
    expect(markers[0].cls).toContain('start-unknown'); expect(markers[0].height).toBeCloseTo(29.9, 9)
    expect(markers[1].cls).toContain('est-unknown'); expect(markers[1].cls).toContain('gplan'); expect(markers[1].height).toBe(32.5)
    expect(markers.map(m => m.title.endsWith(m.id.includes('start') ? 'start unknown' : 'estimate unknown'))).toEqual([true, true])
    // Adopted unknown-value designs have no reference-page counterpart. Keep
    // committed regression baselines and attach the unmasked sign-off evidence.
    for (const marker of markers) {
      await page.evaluate(async id => {
        const { ctx, fx } = await import('/build-home/state.js')
        ctx.snapping = true
        const sec = id.includes('start') ? 'hist' : 'plan', it = ctx.L.secs[sec].items.find(it => it.t.id === id)
        ctx.vp.scrollTop = Math.max(0, ctx.secs[sec].el.offsetTop + it.y - 100); fx.update()
      }, marker.id)
      // Let the real column scheduler finish after the controlled scroll.
      await page.clock.runFor(500)
      const target = page.locator(`.bd-card[data-id="${marker.id}"]`)
      // A locator screenshot can deadlock scrolling with the paused JS clock.
      // The shared page-clip path captures the same element without auto-scrolling.
      const png = await captureStable(target, { animations: 'disabled', caret: 'hide', scale: 'device' }, page)
      await info.attach(`${marker.id}-${width}-${theme}`, { body: png, contentType: 'image/png' })
      expect(png).toMatchSnapshot(`${marker.id}-${width}-${theme}.png`, { threshold: PARITY_THRESHOLD, maxDiffPixels: 0 })
    }
    await info.attach(`s5-semantics-${width}-${theme}`, { body: Buffer.from(JSON.stringify(markers, null, 2)), contentType: 'application/json' })
  } finally { await context.close() }
})
