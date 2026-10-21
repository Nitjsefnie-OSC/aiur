import { test, expect } from '@playwright/test'
import { openVisualRoute } from '../support/visual.mjs'
import { selectProductDataset } from '../support/design-parity.mjs'

test('live ticket shimmer repeats without a seam at card sizes and zoom levels', async ({ page }) => {
  await openVisualRoute(page, { theme: 'dark', palette: 'gruvbox', route: '/build', mode: 'writable' })
  await selectProductDataset(page, 'live')
  const card = page.locator('.bd-card.ag-active').first()
  await expect(card).toBeVisible()
  const glow = card.locator('.bd-glow')
  await expect(glow).toHaveCount(1)
  const { duration, iterations } = await glow.evaluate(el => {
    const animation = el.getAnimations()[0]
    if (!animation) throw new Error('live ticket glow animation is unreachable')
    const timing = animation.effect.getTiming()
    animation.pause()
    return { duration: Number(timing.duration), iterations: timing.iterations }
  })
  expect(duration).toBe(9000)
  expect(iterations).toBe(Infinity)
  expect(await glow.evaluate(el => getComputedStyle(el).backgroundImage)).toContain('repeating-conic-gradient')
  for (const zoom of [0.8, 1, 1.25, 1.5]) {
    await page.evaluate(value => { document.documentElement.style.zoom = value }, zoom)
    const samples = await glow.evaluate((el, duration) => {
      const animation = el.getAnimations()[0]
      return [0, .25, .5, .75, .99, .999, 1].map(fraction => {
        animation.currentTime = duration * fraction
        const style = getComputedStyle(el)
        return { angle: Number.parseFloat(style.getPropertyValue('--bd-a')), background: style.backgroundImage }
      })
    }, duration)
    expect(samples.slice(0, 6).map(sample => sample.angle)).toEqual([0, 90, 180, 270, 356.4, 359.64])
    expect(Math.min(Math.abs(samples.at(-1).angle), Math.abs(samples.at(-1).angle - 360))).toBeLessThan(0.01)
    expect(samples.at(-2).background).not.toBe(samples[0].background)
    expect(samples.at(-1).background).toBe(samples[0].background)
    expect(samples[0].background).toContain('transparent 260deg 360deg')
  }
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await page.locator('.bd-root').evaluate(el => el.classList.add('rm'))
  expect(await glow.evaluate(el => ({ animations: el.getAnimations().length, background: getComputedStyle(el).backgroundImage }))).toEqual({ animations: 0, background: 'none' })
})
