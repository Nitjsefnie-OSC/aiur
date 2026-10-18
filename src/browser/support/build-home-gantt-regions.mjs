import { readFile } from 'node:fs/promises'
import { expect } from '@playwright/test'
import { scrollGanttComposition } from './build-home-gantt-parity.mjs'
import { primeBoardPaint } from './build-home-band-canvas.mjs'

export async function loadGanttRegionHistory(pair, dataset) {
  const snapshot = JSON.parse(await readFile(new URL(`../../test/fixtures/build_home/${dataset}.json`, import.meta.url), 'utf8'))
  await pair.design.evaluate(() => __ganttComposition.allHistory())
  await pair.product.evaluate(async snapshot => {
    const { ctx, S } = await import('/build-home/state.js'), { receive } = await import('/build-home/hook.js')
    S.ready = false
    receive({ ...ctx.snap, kind: 'snapshot', generation: ctx.proto.generation + 1,
      sections: { ...ctx.snap.sections, hist: snapshot.sections.hist }, history: { ...snapshot.history, from: 0, more: false } })
    ctx.snapping = true
  }, snapshot)
  const targets = await pair.design.evaluate(() => __ganttComposition.targets())
  for (const name of ['full', 'two', 'three', 'labelled', 'empty', 'tick', 'line']) expect(targets[name], `fixture missing ${name} Gantt region`).toBeTruthy()
  return targets
}

export async function markGanttRegion(pair, name, target, width) {
  await scrollGanttComposition(pair, Math.max(0, target.y - 100))
  const records = []
  for (const page of [pair.design, pair.product]) records.push(await page.evaluate(({ name, target, width }) => {
    document.querySelector('[data-gantt-clip]')?.remove()
    document.querySelectorAll('[data-gantt-region]').forEach(el => el.removeAttribute('data-gantt-region'))
    const hist = document.querySelector('#bd-sec-hist')
    let el
    if (target.id) el = [...hist.querySelectorAll('.bd-card')].find(el => el.dataset.id.replace('AIUR-', '') === target.id)
    else {
      const selector = name === 'tick' ? '.bd-lbl.tick' : name === 'line' ? '.bd-dl' : '.bd-mk.brk'
      el = [...hist.querySelectorAll(selector)].find(el => Math.abs(parseFloat(el.style.top) - target.y) < 0.01)
    }
    if (!el) throw new Error(`missing rendered ${name} Gantt region`)
    if (width) el.style.width = width + 'px'
    if (name === 'two' || name === 'three') {
      const selected = el._it
      const cluster = [...hist.querySelectorAll('.bd-card')].filter(card => card._it.key === selected.key && card._it.lanes === selected.lanes && card._it.y < selected.y + selected.h && card._it.y + card._it.h > selected.y)
      if (new Set(cluster.map(card => card._it.lane)).size !== target.lanes) throw new Error('render window misses an overlap lane')
      const boxes = cluster.map(card => card.getBoundingClientRect()), x = Math.min(...boxes.map(b => b.x)), y = Math.min(...boxes.map(b => b.y))
      const clip = document.createElement('div'); clip.dataset.ganttClip = ''
      Object.assign(clip.style, { position: 'fixed', left: x + 'px', top: y + 'px', width: Math.max(...boxes.map(b => b.right)) - x + 'px', height: Math.max(...boxes.map(b => b.bottom)) - y + 'px', pointerEvents: 'none' })
      document.body.appendChild(clip); el = clip
    }
    el.dataset.ganttRegion = name
    const rect = el.getBoundingClientRect(), time = el.querySelector('.bd-time'), badge = el.querySelector('.bd-badges span')
    return { width: rect.width, height: rect.height, time: time ? getComputedStyle(time).display : null, badgeFont: badge ? getComputedStyle(badge).fontSize : null,
      icons: [...el.querySelectorAll('svg')].map(svg => { const b = svg.getBoundingClientRect(); return [b.x - rect.x, b.y - rect.y, b.width, b.height] }) }
  }, { name, target, width }))
  expect(records[1]).toEqual(records[0])
  if (width) {
    expect(records[1].time).toBe(width <= 150 ? 'none' : 'block')
    expect(parseFloat(records[1].badgeFont)).toBeCloseTo(13 * (width <= 150 ? 0.62 : 0.7), 2)
  }
  await primeBoardPaint(pair)
  return `[data-gantt-region="${name}"]`
}

export async function markFixedGanttRegion(pair, selector, name) {
  const records = []
  for (const page of [pair.design, pair.product]) records.push(await page.locator(selector).first().evaluate((el, name) => {
    document.querySelectorAll('[data-gantt-region]').forEach(node => node.removeAttribute('data-gantt-region'))
    el.dataset.ganttRegion = name
    const box = el.getBoundingClientRect()
    // Only the external toolbar legend needs the established isolated-region
    // canvas. Cards and the sticky band retain their real composed background.
    if (name === 'legend') Object.assign(el.style, { position: 'fixed', left: '100px', top: '100px', width: box.width + 'px', height: box.height + 'px', boxSizing: 'border-box', margin: '0', zIndex: '10000', background: 'var(--bg)' })
    const origin = el.getBoundingClientRect()
    return { width: origin.width, height: origin.height, icons: [...el.querySelectorAll('svg')].map(svg => {
      const b = svg.getBoundingClientRect(); return [b.x - origin.x, b.y - origin.y, b.width, b.height]
    }) }
  }, name))
  expect(records[1]).toEqual(records[0])
  await primeBoardPaint(pair)
  return `[data-gantt-region="${name}"]`
}
