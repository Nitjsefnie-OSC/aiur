import { readFile } from 'node:fs/promises'
import { expect } from '@playwright/test'
import { alignBoard, alignEtaMask, primeBoardPaint } from './build-home-band-canvas.mjs'
import { installScrollPaint, flushScrollPaint } from './build-home-scroll-paint.mjs'
import { waitParityReady, FIXTURE_META } from './design-parity.mjs'

const source = await readFile(new URL('../../test/fixtures/build_home/design-source/assets/build.js', import.meta.url), 'utf8')
const anchor = '  window.AiurBuild = {'
expect(source.split(anchor)).toHaveLength(2)
const probe = source.replace(anchor, `window.__ganttComposition = {
  stop() { S.ready = false; snapping = true; },
  scroll(top) { vp.scrollTop = top; update(); },
  positions() { return { now: Math.max(0, secs.hist.el.offsetTop + secs.hist.el.offsetHeight - 46), hist: 0, plan: secs.plan.el.offsetTop }; }
};\n${anchor}`)

export async function freezeGanttComposition(pair) {
  // Freeze before the first scroll can page history, preserving the same loaded rows.
  const hook = await readFile(new URL('../../priv/static/build-home/hook.js', import.meta.url), 'utf8')
  expect(hook.split('S.ready = true;')).toHaveLength(2)
  await pair.product.route('**/build-home/hook.js', route => route.fulfill({ contentType: 'text/javascript', body: hook.replace('S.ready = true;', 'S.ready = false;') }))
  await pair.product.reload(); await waitParityReady(pair.product, 'board', 'product', true)
  await pair.design.route('**/assets/build.js*', route => route.fulfill({ contentType: 'text/javascript', body: probe }))
  await pair.design.reload(); await waitParityReady(pair.design, 'board', 'design', true)
  await pair.design.evaluate(() => __ganttComposition.stop())
  await pair.product.evaluate(async () => {
    const { S, ctx } = await import('/build-home/state.js'); S.ready = false; ctx.snapping = true
  })
  await alignBoard(pair)
  for (const page of [pair.design, pair.product]) await page.locator('#bd-vp').evaluate(el => {
    document.body.style.minHeight = Math.ceil(el.getBoundingClientRect().bottom + scrollY) + 'px'
  })
  // Existing C9-T08 exception only: C7-T03 owns ETA copy. Do not mask cards, edges or band geometry.
  pair.allowlist = pair.allowlist.map(entry => entry.id === 'now-band-eta-pending' ? { ...entry, kind: 'pixel-mask', selector: '.bd-now-eta' } : entry)
  await alignEtaMask(pair)
  await Promise.all([pair.design, pair.product].map(async page => {
    await page.clock.setSystemTime(FIXTURE_META.now)
    await installScrollPaint(page)
  }))
}

export async function scrollGanttComposition(pair, top) {
  await pair.design.evaluate(top => __ganttComposition.scroll(top), top)
  await pair.product.evaluate(async top => {
    const { ctx, fx } = await import('/build-home/state.js'); ctx.vp.scrollTop = top; fx.update()
  }, top)
  // Native scroll dispatch is not driven by the paused JS clock. Flush its queued paint,
  // then re-prime the sticky canvas using the same path as the Now-band parity suite.
  await Promise.all([pair.design, pair.product].map(async page => {
    await page.locator('#bd-vp').evaluate(vp => vp.dispatchEvent(new Event('scroll')))
    await flushScrollPaint(page)
  }))
  await primeBoardPaint(pair)
  const positions = await Promise.all([pair.design, pair.product].map(page => page.locator('#bd-vp').evaluate(vp => vp.scrollTop)))
  expect(positions[1]).toBe(positions[0])
}
