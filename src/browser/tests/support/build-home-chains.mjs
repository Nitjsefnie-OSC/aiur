import { fileURLToPath } from 'node:url'
import { expect } from '@playwright/test'

export const card = (page, id) => page.locator(`.bd-card[data-id="${id}"]`).first()
export const tree = page => page.locator('#bd-tree')
export const tray = page => page.locator('.bd-lt')

export async function open(page, { trees = true, dataset = 'chains', modal = false } = {}) {
  if (modal) await page.addInitScript(() => {
    // Register before the hook: a bubble-only tree handler would close both layers.
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') document.querySelector('#tk-backdrop.show')?.remove()
    })
  })
  await page.route(/\/build-home\/[\w-]+\.js$/, route => route.fulfill({
    path: fileURLToPath(new URL('../../../priv/static/build-home/' + new URL(route.request().url()).pathname.split('/').at(-1), import.meta.url)),
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
export async function reveal(page, id) {
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
export async function lock(page, id) {
  await reveal(page, id)
  await card(page, id).hover()
  await expect(tray(page)).toHaveClass(/show/)
  await expect.poll(() => page.evaluate(() => st.ctx.hoverId)).toBe(String(id))
  await page.waitForTimeout(230) // Let the tab finish moving before aiming at its lock button.
  const button = page.locator('[data-lt="lock"]')
  // A dense board can finish shifting after the initial hover. Aim at the live
  // tab bounds and verify the pointer hits the button before pressing it.
  await expect(async () => {
    await card(page, id).hover()
    await expect.poll(() => page.evaluate(() => st.ctx.hoverId), { timeout: 500 }).toBe(String(id))
    await page.waitForTimeout(230)
    const target = await button.boundingBox()
    await page.mouse.move(target.x + target.width / 2, target.y + target.height / 2)
    await expect.poll(() => button.evaluate(el => el.matches(':hover')), { timeout: 500 }).toBe(true)
    await expect.poll(() => page.evaluate(() => st.ctx.hoverId), { timeout: 500 }).toBe(String(id))
  }).toPass({ timeout: 5000 })
  await page.mouse.down(); await page.mouse.up()
  await expect(page.locator('[data-lt="lock"]')).toHaveAttribute('aria-pressed', 'true')
  await expect.poll(() => page.evaluate(() => st.ctx.lockId)).toBe(String(id))
}
export async function whole(page, id) {
  await lock(page, id)
  await page.locator('[data-lt="tree"]').click()
  await expect(tree(page)).toBeVisible()
}
