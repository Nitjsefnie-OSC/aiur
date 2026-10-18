import { readFile } from 'node:fs/promises'
import { test, expect } from '@playwright/test'
import { openParityPair, expectDesignParity, PARITY_VIEWPORTS } from '../support/design-parity.mjs'

const allCells = ['live', 'dense'].flatMap(dataset => PARITY_VIEWPORTS.flatMap(size => ['dark', 'light'].flatMap(theme => ['gruvbox', 'aiur'].map(palette => ({ dataset, ...size, theme, palette })))))
const cells = allCells
async function openFiltersPair(browser, cell, options) {
  const root = test.info().project.metadata.filtersRoot
  const source = root ? { newContext: async opts => {
    const context = await browser.newContext(opts), newPage = context.newPage.bind(context)
    context.newPage = async () => {
      const page = await newPage(), goto = page.goto.bind(page)
      page.goto = async (...args) => {
        await page.route('**/build-home/*.js', async route => route.fulfill({ contentType: 'text/javascript', body: await readFile(root + '/src/priv/static/build-home/' + new URL(route.request().url()).pathname.split('/').at(-1), 'utf8') }))
        return goto(...args)
      }
      return page
    }
    return context
  } } : browser
  return openParityPair(source, cell, options)
}
async function normalize(page) {
  return page.locator('#bd-filters').evaluate(el => {
    const copy = el.cloneNode(true)
    for (const node of [copy, ...copy.querySelectorAll('*')]) {
      for (const attr of [...node.attributes]) if (attr.name.startsWith('aria-') || attr.name === 'role') node.removeAttribute(attr.name)
      if (node.tagName === 'IMG') node.setAttribute('src', node.getAttribute('src').split('/').at(-1))
    }
    return copy.outerHTML
  })
}
for (const cell of cells) test(`filter parity ${cell.dataset} ${cell.viewport.width} ${cell.theme} ${cell.palette}`, async ({ browser }) => {
  test.setTimeout(180000)
  const pair = await openFiltersPair(browser, cell)
  try {
    const groups = cell.viewport.width === 1024 ? [] : cell.dataset === 'live' ? ['epic', 'feature', 'model', 'tstate', 'astate'] : ['feature']
    for (const key of [null, ...groups]) {
      if (key) for (const page of [pair.design, pair.product]) await page.locator(`[data-g="${key}"]`).dispatchEvent('click')
      expect(await normalize(pair.product)).toBe(await normalize(pair.design))
      await expectDesignParity(pair, { name: `toolbar-${key ?? 'closed'}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '.bd-toolbar', preserveAnimations: true })
      if (key) await expectDesignParity(pair, { name: `popover-${key}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '#bd-pop', preserveAnimations: true })
    }
  } finally { await pair.close() }
})

for (const cell of cells.filter(c => c.dataset === 'live')) for (const query of ['model=claude&tstate=merged,failed&astate=active', 'epic=docs']) test(`selected viewport ${cell.viewport.width} ${cell.theme} ${cell.palette} ${query}`, async ({ browser }) => {
  const pair = await openFiltersPair(browser, cell, { query })
  try {
    for (const page of [pair.design, pair.product]) {
      await expect(page.locator('.bd-fg')).toHaveCount(5)
      if (query.startsWith('model=')) await page.locator('[data-g="tstate"]').dispatchEvent('click')
    }
    expect(await normalize(pair.product)).toBe(await normalize(pair.design))
    await expectDesignParity(pair, { name: `viewport-${cell.viewport.width}-${cell.theme}-${cell.palette}-${query.split('=')[0]}`, preserveAnimations: true })
  } finally { await pair.close() }
})
