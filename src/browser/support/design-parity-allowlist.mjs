import { test } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { basename } from 'node:path'

const nonempty = value => typeof value === 'string' && value.trim().length > 0
const kinds = ['design-removal', 'pixel-mask', 'design-style', 'property', 'motion', 'axe', 'copy']
const removals = new WeakMap()
export async function loadAllowlist(source = new URL('./design-parity-allowlist.json', import.meta.url)) {
  const entries = JSON.parse(await readFile(source, 'utf8'))
  if (!Array.isArray(entries)) throw new Error('allowlist must be an array')
  const ids = new Set()
  for (const entry of entries) {
    const a = entry.approval
    const valid = nonempty(entry.id) && !ids.has(entry.id) && kinds.includes(entry.kind) && nonempty(entry.selector) && nonempty(entry.reason)
      && !Object.hasOwn(entry, 'approved') && a && nonempty(a.ref)
      && (entry.spec == null || (nonempty(entry.spec) && /^[a-z0-9-]+\.browser\.spec\.mjs$/.test(entry.spec)))
      && (a.status === 'pending-sign-off' || (a.status === 'approved' && a.by === 'Kevin' && /^\d{4}-\d{2}-\d{2}$/.test(a.date) && !Number.isNaN(Date.parse(a.date)) && new Date(a.date).toISOString().slice(0, 10) === a.date))
      && Object.entries({ css: 'design-style', property: 'property', rule: 'axe', path: 'motion' }).every(([field, kind]) => entry.kind === kind ? nonempty(entry[field]) : entry[field] == null)
      && (entry.kind !== 'motion' || !/[?{}]/.test(entry.path))
      && (entry.productWhen == null || nonempty(entry.productWhen))
      && Object.entries(entry.cells ?? {}).every(([key, value]) => ['viewport', 'theme', 'palette', 'dataset'].includes(key) && nonempty(value))
    if (!valid) throw new Error(`invalid allowlist entry ${entry.id ?? '(unnamed)'}`)
    ids.add(entry.id)
  }
  reportPending(entries)
  return entries
}

export function reportPending(entries) {
  for (const entry of entries.filter(e => e.approval.status === 'pending-sign-off')) {
    const description = `${entry.id}: pending-sign-off (${entry.approval.ref})`
    console.log(description)
    const annotations = test.info().annotations
    if (!annotations.some(a => a.type === 'pending-sign-off' && a.description === description)) annotations.push({ type: 'pending-sign-off', description })
  }
}

const cellMatches = (entry, cell) => Object.entries(entry.cells ?? {}).every(([key, value]) => cell[key] === value)

// Axe reports a CSS target rather than an element. Resolve that target in the
// page, then compare the element to the narrowly recorded allowlist selector.
// Keeping the rule enabled means every non-allowlisted violation still fails.
export async function auditWithAllowlist(page, audit, entries, cell, scope, spec = basename(test.info().file)) {
  const active = entries.filter(entry => entry.kind === 'axe' && (!entry.spec || entry.spec === spec) && cellMatches(entry, cell))
  const candidates = []

  for (const bucket of [audit.violations, audit.incomplete]) {
    for (const result of bucket) {
      for (const node of result.nodes) {
        const matches = active.filter(entry => entry.rule === result.id)
        if (matches.length) candidates.push({ bucket, result, node, matches })
      }
    }
  }

  const resolved = await page.evaluate(({ items, scope }) => items.map(({ target, matches }) => {
    const scoped = matches.filter(entry => entry.selector === scope)
    if (scoped.length) return scoped.map(entry => entry.id)
    const node = document.querySelector(target.join(' '))
    return node ? matches.filter(entry => node.matches(entry.selector)).map(entry => entry.id) : []
  }), { items: candidates.map(({ node, matches }) => ({ target: node.target, matches })), scope })

  const removed = new Set(resolved.flat())
  for (const entry of active) {
    if (!removed.has(entry.id)) throw new Error(`stale allowlist entry ${entry.id}`)
  }

  for (let index = 0; index < candidates.length; index++) {
    if (resolved[index].length) candidates[index].result.nodes = candidates[index].result.nodes.filter(node => node !== candidates[index].node)
  }
  audit.violations = audit.violations.filter(result => result.nodes.length)
  audit.incomplete = audit.incomplete.filter(result => result.nodes.length)

  return audit
}

export async function applyAllowlist(pair, cell, entries) {
  entries ??= pair.allowlist ?? await loadAllowlist()
  const masks = { designMask: [], productMask: [] }
  for (const entry of entries) {
    if (entry.spec && entry.spec !== basename(test.info().file)) continue
    if (entry.kind === 'motion') continue
    // Capability-scoped differences apply only where the product exposes that capability.
    if (entry.productWhen && !await pair.product.locator(entry.productWhen).count()) continue
    if (!Object.entries(entry.cells ?? {}).every(([key, value]) => (key === 'viewport' ? `${cell.viewport.width}x${cell.viewport.height}` : cell[key]) === value)) continue
    // Motion paths have their own stale-difference check.
    const pages = entry.kind === 'pixel-mask' ? [pair.design, pair.product] : [pair.design]
    if (entry.kind === 'design-removal' && removals.get(pair.design)?.has(entry.id)) continue
    for (const page of pages) {
      if (!await page.locator(entry.selector).count()) throw new Error(`stale allowlist entry ${entry.id}`)
    }
    if (entry.kind === 'design-removal') {
      await pair.design.locator(entry.selector).evaluateAll(nodes => nodes.forEach(n => n.remove()))
      if (!removals.has(pair.design)) removals.set(pair.design, new Set())
      removals.get(pair.design).add(entry.id)
    }
    if (entry.kind === 'design-style') await pair.design.addStyleTag({ content: entry.css })
    if (entry.kind === 'pixel-mask') {
      masks.designMask.push(pair.design.locator(entry.selector))
      masks.productMask.push(pair.product.locator(entry.selector))
    }
    // A copy difference changes text length, so both masks get one box wherever the copy renders.
    if (entry.kind === 'copy' && entry.mask) {
      const nodes = [pair.design, pair.product].map(page => page.locator(entry.mask))
      if ((await Promise.all(nodes.map(node => node.count()))).every(n => n === 1)) {
        const width = Math.max(...await Promise.all(nodes.map(node => node.evaluate(el => el.getBoundingClientRect().width))))
        for (const node of nodes) await node.evaluate((el, w) => { el.style.display = 'inline-block'; el.style.minWidth = w + 'px' }, width)
        masks.designMask.push(nodes[0])
        masks.productMask.push(nodes[1])
      }
    }
  }
  return masks
}
