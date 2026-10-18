import { test, expect } from '@playwright/test'
import { openParityPair, expectDesignParity, PARITY_VIEWPORTS } from '../support/design-parity.mjs'

const cells = ['live', 'dense'].flatMap(dataset => PARITY_VIEWPORTS.flatMap(size => ['dark', 'light'].flatMap(theme => ['gruvbox', 'aiur'].map(palette => ({ dataset, ...size, theme, palette })))))
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
  // Keep inherited paint and container queries, but align capture to an integer pixel origin.
  await page.locator('#bd-filters').evaluate(host => {
    const root = host.closest('.bd-root'), wrap = document.createElement('div'); wrap.className = 'bd-toolbar'
    Object.assign(wrap.style, { position: 'fixed', top: '0', left: '0', width: root.clientWidth + 'px', height: '300px', alignItems: 'flex-start', background: 'var(--bg)', zIndex: '9999' })
    root.append(wrap); wrap.append(host)
  })
}
for (const cell of cells) test(`filter parity ${cell.dataset} ${cell.viewport.width} ${cell.theme} ${cell.palette}`, async ({ browser }) => {
  test.setTimeout(180000)
  const pair = await openParityPair(browser, cell)
  try {
    for (const page of [pair.design, pair.product]) await isolateFilters(page)
    for (const key of [null, ...(cell.dataset === 'live' ? ['epic', 'feature', 'model', 'tstate', 'astate'] : ['feature'])]) {
      if (key) for (const page of [pair.design, pair.product]) await page.locator(`[data-g="${key}"]`).click()
      expect(await normalize(pair.product)).toBe(await normalize(pair.design))
      await expectDesignParity(pair, { name: `filters-${key ?? 'closed'}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '#bd-filters' })
      if (key) await expectDesignParity(pair, { name: `popover-${key}-${cell.dataset}-${cell.viewport.width}-${cell.theme}-${cell.palette}`, region: '#bd-pop' })
    }
  } finally { await pair.close() }
})

for (const query of ['model=claude&tstate=merged,failed&astate=active', 'epic=docs']) test(`selected filters parity ${query}`, async ({ browser }) => {
  const pair = await openParityPair(browser, { dataset: 'live', ...PARITY_VIEWPORTS[0], theme: 'dark', palette: 'gruvbox' }, { query })
  try {
    for (const page of [pair.design, pair.product]) { await isolateFilters(page); await page.locator('[data-g="tstate"]').click() }
    expect(await normalize(pair.product)).toBe(await normalize(pair.design))
    await expectDesignParity(pair, { name: 'selected-' + query.split('=')[0], region: '#bd-filters' })
    await expectDesignParity(pair, { name: 'selected-popover-' + query.split('=')[0], region: '#bd-pop' })
  } finally { await pair.close() }
})
