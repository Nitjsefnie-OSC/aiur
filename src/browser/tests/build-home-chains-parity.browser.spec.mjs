import { test, expect } from '@playwright/test'
import { openParityPair, PARITY_VIEWPORTS } from '../support/design-parity.mjs'
import { settleAnimations } from './support/browser-helpers.mjs'

test.setTimeout(120_000)
const cells = PARITY_VIEWPORTS.flatMap(v => ['dark', 'light'].map(theme => ({ dataset: 'live', ...v, theme, palette: 'gruvbox' })))
for (const cell of cells) test(`tree geometry and labels match design ${cell.viewport.width} ${cell.theme}`, async ({ browser }) => {
  const pair = await openParityPair(browser, cell, { query: '?trees=1' })
  try {
    // The exact root has a known acyclic chain on the frozen live dataset.
    for (const page of [pair.design, pair.product]) {
      await page.evaluate(() => { document.querySelector('#bd-vp').scrollTop = document.querySelector('#bd-sec-plan').offsetTop })
      await page.waitForTimeout(800)
      const card = page.locator('.bd-card[data-id="615"], .bd-card[data-id="AIUR-615"]').first()
      await expect(card).toHaveCount(1)
      await card.dispatchEvent(page === pair.product ? 'pointerover' : 'mouseover', { pointerType: 'mouse' })
      await expect(page.locator('.bd-lt.show')).toHaveCount(1)
      await page.locator('[data-lt="lock"]').evaluate(el => el.click())
      await expect(page.locator('.bd-lt.locked')).toHaveCount(1)
      await page.locator('[data-lt="tree"]').evaluate(el => el.click())
      await settleAnimations(page, '#bd-tree')
    }
    const record = page => page.locator('#bd-tree').evaluate(host => ({
      header: host.querySelector('.bd-tree-h span').textContent,
      transform: host.querySelector('.bd-tree-in').style.transform,
      size: ['width', 'height'].map(k => host.querySelector('.bd-tree-in').style[k]),
      nodes: [...host.querySelectorAll('.bd-tn')].map(el => ({ ref: el.querySelector('b').textContent,
        title: el.querySelector('.bd-tn1 > span').textContent, status: el.querySelector('em').textContent,
        pos: ['left', 'top', 'width', 'height'].map(k => el.style[k]) })).sort((a,b) => a.ref.localeCompare(b.ref))
    }))
    expect(await record(pair.product)).toEqual(await record(pair.design))
    await expect(pair.product.getByRole('dialog', { name: 'Dependency tree' })).toBeVisible()
    await pair.product.keyboard.press('Escape')
    await expect(pair.product.locator('#bd-tree')).toBeHidden()
  } finally { await pair.close() }
})
