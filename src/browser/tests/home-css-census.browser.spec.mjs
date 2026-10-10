import { test, expect } from '@playwright/test'
import { readFile, writeFile } from 'node:fs/promises'
import { parityContextOptions } from '../support/design-parity.mjs'
import { HOME_MATRIX, openHomeState } from '../support/home-css-states.mjs'
import { census, renderHomeCss, ownsBuildLine, DEAD } from '../support/home-css-census.mjs'

const all = []
const combined = new Map()
const key = r => `${r.source}:${r.line}:${r.selector}:${JSON.stringify(r.context)}`
let trees
for (const cell of HOME_MATRIX) test(`future re-import guard: dead selectors unused in ${cell.name}`, async ({ browser }) => {
  const context = await browser.newContext(parityContextOptions(cell))
  try {
    const page = await context.newPage()
    await openHomeState(page, cell)
    const records = await census(page)
    all.push({ state: cell.name, rules: structuredClone(records.filter(r => r.selector)) })
    for (const rule of records.filter(r => r.selector)) {
      if (!combined.has(key(rule))) combined.set(key(rule), structuredClone(rule))
      else rule.matches.forEach((m, i) => { combined.get(key(rule)).matches[i].count += m.count })
    }
    trees ??= records.filter(r => r.tree)
    const dead = records.filter(r => r.selector).flatMap(r => r.matches.filter(m => DEAD.test(m.selector)))
    expect(dead.filter(m => m.count > 0), 'dead selector matched').toEqual([])
  } finally { await context.close() }
})

test.afterAll(async () => {
  if (!trees) return
  const update = rules => rules.forEach(r => r.children ? update(r.children) : r.selector ? Object.assign(r, combined.get(key(r))) : null)
  trees.forEach(r => update(r.tree))
  const records = [...combined.values(), ...trees]
  const { css, parts, shadowed } = renderHomeCss(records)
  const dead = records.filter(r => r.selector).flatMap(r => r.matches.filter(m => DEAD.test(m.selector)).map(m => ({ source: r.source, line: r.line, ...m })))
  const zeroMatches = records.filter(r => r.source === 'C' && r.selector && ownsBuildLine(r.line)).flatMap(r => r.matches.filter(m => !m.count && !DEAD.test(m.selector) && !(r.line === 983 && m.selector.includes('.ax-menu'))).map(m => ({ source: r.source, line: r.line, context: r.context, ...m })))
  await writeFile(test.info().outputPath('home-css-census.json'), JSON.stringify({ states: all, dead, zeroMatches, shadowed, css, parts, trees }, null, 2))
})


test('ordered stylesheet imports preserve source order and Safari blur fallbacks', async () => {
  const entry = new URL('../../priv/static/build-home/home.css', import.meta.url)
  const imports = [...(await readFile(entry, 'utf8')).matchAll(/@import url\("home\/([^"/]+)"\);/g)]
  expect(imports.length).toBeGreaterThan(0)
  expect(imports.map(([, name]) => Number(name.slice(0, 2)))).toEqual(imports.map((_, i) => i + 1))
  const parts = await Promise.all(imports.map(([, name]) => readFile(new URL(`home/${name}`, entry), 'utf8')))
  for (const part of parts) expect(part.trimEnd().split('\n').length).toBeLessThan(500)
  const css = parts.join('\n')
  const markers = [...css.matchAll(/\/\* ([HC]):(\d+) \*\//g)]
  expect(markers.map(([, source, line]) => (source === 'C' ? 10000 : 0) + Number(line))).toEqual(
    markers.map(([, source, line]) => (source === 'C' ? 10000 : 0) + Number(line)).sort((a, b) => a - b))
  const blurRules = [...css.replace(/\/\*[\s\S]*?\*\//g, '').matchAll(/([^{}]+)\{([^{}]*)\}/g)]
    .filter(([, , body]) => body.includes('-webkit-backdrop-filter:'))
    .map(([, selector, body]) => ({ selector: selector.trim(), declarations: body.match(/(?:-webkit-)?backdrop-filter:[^;]+;/g) }))
  expect(blurRules).toEqual([
    { selector: '.bd-tree', declarations: ['backdrop-filter: blur(10px) saturate(.7);', '-webkit-backdrop-filter: blur(10px) saturate(.7);'] },
    { selector: '.bd-now, html[data-palette="gruvbox"] .bd-now', declarations: ['backdrop-filter: blur(5px);', '-webkit-backdrop-filter: blur(5px);'] },
  ])
})
