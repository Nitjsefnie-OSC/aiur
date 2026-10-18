import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { test } from 'node:test'
import { readFileSync } from 'node:fs'

const require = createRequire(import.meta.url)
const browserRoot = fileURLToPath(new URL('..', import.meta.url))
const spec = 'tests/build-home-motion.browser.spec.mjs'

function collect(config, full, grep, selectedSpec = spec, extra = []) {
  const child = spawnSync(process.execPath, [require.resolve('@playwright/test/cli'), 'test', selectedSpec, ...extra, '--config', config, '--list', '--reporter=json', ...(grep ? ['--grep', grep] : [])], {
    cwd: browserRoot,
    env: { ...process.env, AIUR_BROWSER_PORT: '43210', AIUR_PARITY_FULL: full ? '1' : '' },
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024
  })
  assert.equal(child.status, 0, child.error?.message || child.stderr)
  const report = JSON.parse(child.stdout)
  const titles = []
  function visit(suites = []) {
    for (const suite of suites) {
      titles.push(...suite.specs.map(spec => spec.title))
      visit(suite.suites)
    }
  }
  visit(report.suites)
  return { titles: titles.sort(), config: report.config }
}

test('chain parity defaults to four routine cells and retains the tagged full matrix', () => {
  const chains = 'tests/build-home-chains-parity.browser.spec.mjs'
  const routine = collect('playwright.design-parity.config.mjs', false, undefined, chains).titles
  assert.deepEqual(routine, ['dark aiur', 'dark gruvbox', 'light aiur', 'light gruvbox']
    .map(cell => 'P1–P4 chain pixel parity 1440 ' + cell).sort())
  const full = collect('playwright.design-parity.config.mjs', true, '@full-parity', chains).titles
  assert.equal(full.length, 12)
  for (const width of [1440, 1024, 390]) assert.equal(full.filter(title => title.includes(' ' + width + ' ')).length, 4)
  assert.deepEqual(collect('playwright.design-parity.config.mjs', true, '@routine-parity', chains).titles, routine)
})

test('routine motion collects every determinism case; full mode preserves the original matrix', () => {
  const routine = collect('playwright.build-home-motion.config.mjs', false)
  assert.equal(routine.titles.filter(title => title.startsWith('design determinism:')).length, 76)
  assert.equal(routine.titles.filter(title => title.startsWith('clock probe:')).length, 2)
  assert.ok(routine.titles.every(title => /^(clock probe:|harness self-check:|design determinism:)/.test(title)))
  assert.equal(routine.config.workers, 2)
  assert.equal(routine.config.fullyParallel, true)

  const full = collect('playwright.build-home-motion.config.mjs', true)
  const original = collect('playwright.design-parity.config.mjs', true)
  assert.ok(full.titles.length > routine.titles.length)
  assert.deepEqual(full.titles, original.titles)
  assert.deepEqual(routine.titles, original.titles.filter(title => /^(clock probe:|harness self-check:|design determinism:)/.test(title)))
  assert.ok(full.titles.includes('full sign-off: no missing ports or stale motion entries'))
  assert.equal(full.config.workers, 1)
  assert.equal(full.config.fullyParallel, false)
})

test('band suite collects every product snap and the required live grain and pulse cells', () => {
  const scripts = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')).scripts
  const script = scripts['test:build-home-band-motion'], grep = /--grep '([^']+)'/.exec(script)?.[1]
  assert.ok(grep, 'band motion script must select its product cases')
  const { titles } = collect('playwright.design-parity.config.mjs', false, grep)
  for (const name of ['settle-near-top', 'settle-near-bottom', 'pinned', 'guard-up', 'guard-down', 'tall-band', 'list-view', 'scroll-curve', 'scrollbar-drag', 'reduce']) {
    assert.equal(titles.filter(title => title === 'snap.' + name).length, 3, name)
  }
  assert.equal(titles.filter(title => title === 'grain.static .bd-now').length, 1)
  assert.equal(titles.filter(title => title === 'inventory .bd-now-h > b i').length, 1)
  assert.equal(titles.length, 32)
  assert.ok(scripts['test:core'].includes('npm run test:build-home-band-motion'))
})


test('band parity shards collect the complete matrix exactly once', () => {
  const scripts = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')).scripts
  const parity = 'tests/build-home-now-band-parity.browser.spec.mjs'
  const whole = collect('playwright.design-parity.config.mjs', false, undefined, parity).titles
  const placed = []
  for (let i = 1; i <= 4; i++) {
    const name = 'test:build-home-band-parity:' + i, script = scripts[name]
    assert.ok(script.includes(parity))
    assert.ok(script.includes('--fully-parallel'))
    const shard = /--shard=(\d+\/\d+)/.exec(script)?.[1]
    assert.ok(shard)
    const { titles } = collect('playwright.design-parity.config.mjs', false, undefined, parity, ['--fully-parallel', '--shard=' + shard])
    assert.equal(titles.length, 26)
    placed.push(...titles)
    assert.ok(scripts['test:core'].includes('npm run ' + name))
  }
  assert.equal(whole.length, 104)
  assert.equal(new Set(placed).size, 104)
  assert.deepEqual(placed.sort(), whole)
})
