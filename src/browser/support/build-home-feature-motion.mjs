import { expect } from '@playwright/test'
import { prepareFilterCapture } from './build-home-filter-parity.mjs'
import { FIXTURE_META } from './design-parity-environment.mjs'

export async function prepareFeatureMotion(pair) {
  // Focus loads the whole feature; preload both windows before sampling its fade.
  await pair.product.evaluate(async () => {
    const { ctx } = await import('/build-home/state.js')
    await (await import('/build-home/history.js')).ensureFrom(ctx.D.features.khala.oldest)
  })
  const count = page => page.locator('#bd-sec-hist .bd-sech em').last().textContent()
  const target = await count(pair.product)
  for (let days = 0; await count(pair.design) !== target; days++) {
    if (days >= 64) throw new Error('Feature history windows did not align')
    await pair.design.locator('#bd-vp').evaluate(vp => { vp.scrollTop = 0; vp.dispatchEvent(new Event('scroll')) })
    await pair.design.clock.runFor(32)
  }
  expect(await count(pair.design)).toBe(target)
  await prepareFilterCapture(pair)
  const boxes = await Promise.all([pair.design, pair.product].map(page => page.locator('#build-root').boundingBox()))
  const width = Math.min(...boxes.map(box => box.width))
  for (const page of [pair.design, pair.product]) {
    // Isolate the board from the exterior shell's scrollbar gutter (reference HTML:154).
    await page.locator('#build-root').evaluate((root, width) => { root.style.width = width + 'px' }, width)
    await page.clock.runFor(800)
    await page.evaluate(() => {
      // Sample history, away from the independently tested Live-band snap guard.
      document.querySelector('#bd-vp').scrollTop = 500
    })
    await page.clock.runFor(800)
    await page.clock.setSystemTime(FIXTURE_META.now)
    await page.evaluate(() => document.getAnimations().forEach(a => { if (Number.isFinite(a.effect?.getComputedTiming().endTime)) a.finish() }))
  }
}
