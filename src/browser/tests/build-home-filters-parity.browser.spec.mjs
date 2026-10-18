import { readFile } from 'node:fs/promises'
import { test, expect } from '@playwright/test'
import { openParityPair, expectDesignParity, PARITY_VIEWPORTS } from '../support/design-parity.mjs'

const allCells = ['live', 'dense'].flatMap(dataset => PARITY_VIEWPORTS.flatMap(size => ['dark', 'light'].flatMap(theme => ['gruvbox', 'aiur'].map(palette => ({ dataset, ...size, theme, palette })))))
// Routine CI spans each breakpoint and palette; full sign-off retains every design cell.
const cells = process.env.AIUR_PARITY_FULL === '1' ? allCells : allCells.filter(c =>
  c.dataset === 'live' && (c.viewport.width === 1440 && c.theme === 'dark' && c.palette === 'gruvbox' || c.viewport.width === 1024 && c.theme === 'light' && c.palette === 'aiur' || c.viewport.width === 390 && c.theme === 'dark' && c.palette === 'aiur') ||
  c.dataset === 'dense' && (c.viewport.width === 1440 && c.theme === 'light' && c.palette === 'gruvbox' || c.viewport.width === 390 && c.theme === 'dark' && c.palette === 'gruvbox'))
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
async function isolateFilters(page) {
  // Freeze the fixture socket before moving the root; a server patch would otherwise mount a second copy.
  await page.evaluate(() => window.liveSocket?.disconnect())
  // Keep inherited paint and container queries, but align capture to an integer pixel origin.
  await page.locator('#bd-filters').evaluate(host => {
    const fields = ['fontFamily', 'fontSize', 'lineHeight', 'color'], before = fields.map(k => getComputedStyle(host)[k])
    const root = host.closest('.bd-root'), width = root.clientWidth, wrap = document.createElement('div'); wrap.className = 'bd-toolbar'
    // Container queries also establish fixed-position containing blocks; detach the real root to align those too.
    document.body.append(root)
    Object.assign(root.style, { position: 'fixed', top: '0', left: '0', width: width + 'px', height: '100vh', zIndex: '2147483647' })
    Object.assign(wrap.style, { position: 'fixed', top: '0', left: '0', width: root.clientWidth + 'px', height: '100vh', alignItems: 'flex-start', background: 'var(--bg)', zIndex: '9999' })
    root.append(wrap); wrap.append(host)
    if (JSON.stringify(fields.map(k => getComputedStyle(host)[k])) !== JSON.stringify(before)) throw new Error('filter capture changed inherited paint')
    const box = host.querySelector('.bd-fg').getBoundingClientRect()
    if (document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)?.closest('#bd-filters') !== host) throw new Error('filter capture is covered by page chrome')
  })
}
for (const cell of cells) test(`filter parity ${cell.dataset} ${cell.viewport.width} ${cell.theme} ${cell.palette}`, async ({ browser }) => {
  test.setTimeout(180000)
  const pair = await openFiltersPair(browser, cell)
  try {
    for (const page of [pair.design, pair.product]) await isolateFilters(page)
    for (const key of [null, ...(cell.dataset === 'live' ? ['epic', 'feature', 'model', 'tstate', 'astate'] : ['feature'])]) {
      if (key) for (const page of [pair.design, pair.product]) await page.locator(`[data-g="${key}"]`).dispatchEvent('click')
      expect(await normalize(pair.product)).toBe(await normalize(pair.design))
      await expectDesignParity(pair, { name: `filters-${key ?? 'closed'}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '#bd-filters' })
      if (key) await expectDesignParity(pair, { name: `popover-${key}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '#bd-pop' })
    }
  } finally { await pair.close() }
})

for (const query of ['model=claude&tstate=merged,failed&astate=active', 'epic=docs']) test(`selected filters parity ${query}`, async ({ browser }) => {
  const pair = await openFiltersPair(browser, { dataset: 'live', ...PARITY_VIEWPORTS[0], theme: 'dark', palette: 'gruvbox' }, { query })
  try {
    for (const page of [pair.design, pair.product]) await expect(page.locator('.bd-fg')).toHaveCount(5)
    for (const page of [pair.design, pair.product]) { await isolateFilters(page); await page.locator('[data-g="tstate"]').dispatchEvent('click') }
    expect(await normalize(pair.product)).toBe(await normalize(pair.design))
    await expectDesignParity(pair, { name: 'selected-' + query.split('=')[0], region: '#bd-filters' })
    await expectDesignParity(pair, { name: 'selected-popover-' + query.split('=')[0], region: '#bd-pop' })
  } finally { await pair.close() }
})
