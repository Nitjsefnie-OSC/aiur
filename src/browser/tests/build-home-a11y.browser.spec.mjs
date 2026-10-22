// MP-E8-C12-T05: keyboard, names, the agent-state live region, forced colours and axe on the Build home.
// Each test names the production hunk whose removal makes it fail.
import { test, expect } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'
import { readFileSync } from 'node:fs'
import { dashboardCredentials } from './support/layout-worker.mjs'
import { loadAllowlist } from '../support/design-parity-allowlist.mjs'

test.use({ httpCredentials: dashboardCredentials, timezoneId: 'America/Los_Angeles', viewport: { width: 1440, height: 900 } })
const fixture = name => JSON.parse(readFileSync(new URL(`../../test/fixtures/build_home/${name}.json`, import.meta.url), 'utf8'))
const live = fixture('live'), liveRows = Object.values(live.sections).flat()
let errors
test.beforeEach(({ page }) => { errors = []; page.on('pageerror', error => errors.push(error.message)) })
test.afterEach(() => expect(errors).toEqual([]))

async function open(page, dataset = 'live', query = '') {
  await page.goto('/build-fixture/' + dataset + query)
  await expect(page.locator('#build-root')).toHaveAttribute('data-bd-mounted', '')
  await page.evaluate(async () => { window.st = { ...await import('/build-home/state.js'), ...await import('/build-home/a11y.js') } })
}
const board = page => expect(page.locator('#bd-content .bd-card').first()).toBeVisible()
const card = (page, id) => page.locator(`#bd-content .bd-card[data-id="${id}"]`)
const active = page => page.evaluate(() => ({ id: document.activeElement?.dataset.id ?? null, el: document.activeElement?.id || document.activeElement?.className || '' }))
// Tab forward until a board card has focus; the live band's header buttons sit before its cards in DOM order.
async function tabToCard(page) {
  for (let i = 0; i < 20; i++) {
    await page.keyboard.press('Tab')
    if (await page.evaluate(() => document.activeElement.matches('#bd-content .bd-card'))) return (await active(page)).id
  }
  return null
}
async function reconnect(page) {
  await page.evaluate(() => window.liveSocket.disconnect())
  await expect(page.locator('#build-root')).toHaveAttribute('data-build-socket', 'down')
  await page.evaluate(() => window.liveSocket.connect())
  await expect(page.locator('#build-root')).toHaveAttribute('data-build-socket', 'up')
}
async function diff(page, name) {
  const response = await page.request.get('/build-control/diff?name=' + name)
  expect(response.status(), await response.text()).toBe(200)
}
// Scroll the board so a section is in view and render it.
const reveal = (page, sec) => page.evaluate(sec => { st.ctx.vp.scrollTop = st.ctx.secs[sec].el.offsetTop; st.fx.update() }, sec)
const pureLabel = (page, patch, classes = []) => page.evaluate(({ patch, classes }) => {
  const t = { ...st.ctx.D.byId['599'], ...patch }
  return st.cardLabel(t, st.ctx.D, st.ctx.snap, { contains: c => classes.includes(c) })
}, { patch, classes })

test.describe('card names', () => {
  test('A-1 a live card is a button named by number, title, state, progress, complexity and deps', async ({ page }) => {
    await open(page); await board(page)
    const row = liveRows.find(r => r.id === '599'), children = liveRows.filter(r => r.deps.includes('599')).length
    const expected = `#599 ${row.title}. Agent Claude: Running. ${row.pct}% done. Complexity ${row.cx} of 5. ${row.deps.length} dependencies, unblocks ${children}.`
    expect(await pureLabel(page, {})).toBe(expected)
    await expect(card(page, '599')).toHaveAttribute('aria-label', expected)
    await expect(card(page, '599')).toHaveAttribute('role', 'button')
  })
  test('A-2 unknown progress, complexity and state say unknown, never a plausible default', async ({ page }) => {
    await open(page); await board(page)
    const labels = [await pureLabel(page, { pct: null }), await pureLabel(page, { cx: null }), await pureLabel(page, { agent: { ...live.sections.now[0].agent, state: null } })]
    expect(labels[0]).toContain('progress unknown'); expect(labels[1]).toContain('complexity unknown'); expect(labels[2]).toContain('Agent Claude: state unknown')
    for (const label of labels) expect(label).not.toMatch(/(^|\s)0% done|Complexity 0|—/)
    expect(labels[2]).not.toContain('Running')
  })
  test('A-3 a stale board names the heartbeat time on live cards', async ({ page }) => {
    await open(page, 'offline'); await board(page)
    const at = new Date(fixture('offline').daemon.heartbeat_at).toLocaleTimeString('en-GB', { timeZone: 'America/Los_Angeles', hour: '2-digit', minute: '2-digit' })
    await expect(page.locator('#bd-now .bd-card').first()).toHaveAttribute('aria-label', new RegExp(`, as of ${at}\\.`))
  })
  test('A-4/A-5 CSS-only text and pack rows are spoken; A-6 hostile titles stay text', async ({ page }) => {
    await open(page); await board(page)
    const css = await pureLabel(page, {}, ['ghost', 'also', 'dim'])
    for (const word of ['outside feature', 'also affects', 'dimmed by filter']) expect(css).toContain(word)
    const pack = await pureLabel(page, { id: 'pack:x', num: null, title: 'Port X', sec: 'plan', agent: null, cue: {} })
    expect(pack.startsWith('Not filed yet. Port X.')).toBe(true); expect(pack).not.toMatch(/—|#null/)
    const hostile = '<img src=x onerror="window.__xss=1">'
    await page.evaluate(title => { st.ctx.D.byId['599'].title = title; st.fx.decorateAll() }, hostile)
    await expect(card(page, '599')).toHaveAttribute('aria-label', new RegExp('^#599 ' + hostile.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
    expect(await card(page, '599').locator('img[src="x"]').count()).toBe(0)
    expect(await page.evaluate(() => window.__xss)).toBeUndefined()
  })
  test('A-7 a filter adds and clearing it removes "dimmed by filter"', async ({ page }) => {
    await open(page); await board(page)
    await page.evaluate(() => { st.S.f.model = ['codex']; st.fx.decorateAll() })
    await expect(card(page, '599')).toHaveAttribute('aria-label', /dimmed by filter\.$/)
    await page.evaluate(() => { st.S.f.model = []; st.fx.decorateAll() })
    await expect(card(page, '599')).not.toHaveAttribute('aria-label', /dimmed by filter/)
  })
})

test.describe('keyboard', () => {
  test('K-1 the board is one Tab stop; arrows, Home and End follow reading order', async ({ page }) => {
    await open(page, 'dense'); await board(page)
    const stop = await page.evaluate(() => {
      const stops = [...document.querySelectorAll('#bd-content .bd-card[tabindex="0"]')].map(el => el.dataset.id)
      const top = st.ctx.vp.scrollTop, firstSeen = st.readingOrder().find(it => document.querySelector(`#bd-content .bd-card[data-id="${it.t.id}"]`) &&
        (it.sec === 'now' ? st.ctx.secs.hist.el.offsetTop + st.ctx.L.secs.hist.h : st.ctx.secs[it.sec].el.offsetTop) + it.y + it.h > top)
      return { stops, firstSeen: firstSeen.t.id, cards: document.querySelectorAll('#bd-content .bd-card').length }
    })
    expect(stop.cards).toBeGreaterThan(5); expect(stop.stops).toEqual([stop.firstSeen])
    await page.locator('#bd-tools button:not([disabled])').last().focus()
    expect(await tabToCard(page)).toBe(stop.firstSeen)
    const order = await page.evaluate(() => st.readingOrder().map(it => it.t.id))
    await page.keyboard.press('ArrowDown'); expect((await active(page)).id).toBe(order[order.indexOf(stop.firstSeen) + 1])
    await page.keyboard.press('ArrowUp'); expect((await active(page)).id).toBe(stop.firstSeen)
    // History pages in as the board scrolls, so read the order the key acts on, not the first one.
    const ends = () => page.evaluate(() => [st.readingOrder()[0].t.id, st.readingOrder().at(-1).t.id])
    const [, last] = await ends()
    await page.keyboard.press('End'); expect((await active(page)).id).toBe(last)
    const [first] = await ends()
    await page.keyboard.press('Home'); expect((await active(page)).id).toBe(first)
    expect(await page.locator('#bd-content .bd-card[tabindex="0"]').count()).toBe(1)
  })
  test('K-2 a focused card stays in the DOM when it scrolls out of the render window', async ({ page }) => {
    await open(page, 'dense'); await board(page); await reveal(page, 'plan')
    const id = await page.locator('#bd-sec-plan .bd-card').first().evaluate(el => { el.focus(); return el.dataset.id })
    await page.evaluate(() => { st.ctx.vp.scrollTop += 3000; st.fx.update() })
    expect(await page.evaluate(() => [document.activeElement.dataset.id, document.activeElement.isConnected])).toEqual([id, true])
  })
  test('K-3 Space opens a card like Enter; with ?trees=1 it locks and unlocks the chain', async ({ page }) => {
    await open(page); await board(page); await reveal(page, 'plan')
    const plan = page.locator('#bd-sec-plan .bd-card').first(), id = await plan.getAttribute('data-id')
    await plan.focus(); const before = await page.evaluate(() => st.ctx.vp.scrollTop)
    await page.keyboard.press(' ')
    await expect(page.locator('#tk-backdrop')).toHaveClass(/show/)
    expect(await page.evaluate(() => [st.ctx.vp.scrollTop, st.ctx.lockId])).toEqual([before, null])
    await page.keyboard.press('Escape'); await expect(page.locator('#tk-backdrop')).not.toHaveClass(/show/)
    await expect.poll(() => active(page).then(a => a.id)).toBe(id)

    await open(page, 'live', '?trees=1'); await board(page); await reveal(page, 'plan')
    const locked = page.locator('#bd-sec-plan .bd-card').first(), lockId = await locked.getAttribute('data-id')
    await locked.focus(); const top = await page.evaluate(() => st.ctx.vp.scrollTop)
    await page.keyboard.press(' ')
    await expect(page.locator('.bd-lt')).toHaveClass(/locked/)
    expect(await page.evaluate(() => [st.ctx.lockId, st.ctx.vp.scrollTop])).toEqual([lockId, top])
    await expect(page.locator('#tk-backdrop')).not.toHaveClass(/show/)
    await page.keyboard.press(' '); await expect(page.locator('.bd-lt')).not.toHaveClass(/locked/)
    await page.keyboard.press(' '); await expect(page.locator('.bd-lt')).toHaveClass(/locked/)
    await page.keyboard.press('Escape'); await expect(page.locator('.bd-lt')).not.toHaveClass(/locked/)
  })
  test('K-4 a focused card removed by a diff leaves focus on the board, and Tab still reaches a card', async ({ page }) => {
    await open(page); await board(page); await reveal(page, 'plan')
    await card(page, '607').focus()
    await diff(page, 'a11y-remove-plan')
    await expect(card(page, '607')).toHaveCount(0)
    await expect.poll(() => active(page).then(a => a.el)).toBe('bd-vp')
    expect(await tabToCard(page)).not.toBeNull()
  })
  test('K-5 the modal traps Tab and returns focus to the opener card', async ({ page }) => {
    await open(page); await board(page)
    await card(page, '599').focus(); await page.keyboard.press('Enter')
    await expect(page.locator('#tk-backdrop')).toHaveClass(/show/)
    for (let i = 0; i < 12; i++) {
      await page.keyboard.press(i === 11 ? 'Shift+Tab' : 'Tab')
      expect(await page.evaluate(() => document.querySelector('#tk-modal').contains(document.activeElement))).toBe(true)
    }
    await page.keyboard.press('Escape')
    await expect.poll(() => active(page).then(a => a.id)).toBe('599')
  })
  for (const theme of ['dark', 'light']) test(`K-6 every Tab stop on the page shows a ring (${theme}); a card's ring follows its radius`, async ({ page }) => {
    await open(page); await board(page)
    await page.evaluate(theme => document.documentElement.setAttribute('data-theme', theme), theme)
    await page.locator('body').focus(); const seen = new Set(), bad = []
    for (let i = 0; i < 120; i++) {
      await page.keyboard.press('Tab')
      const f = await page.evaluate(() => {
        const el = document.activeElement, s = getComputedStyle(el)
        // The composer's design focus is its :focus-within frame (C:557), not a ring on the textarea.
        const within = !!el.closest('.cv-in')
        return { key: el.id || el.dataset.id || el.outerHTML.slice(0, 90), ring: s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0, within,
          card: el.matches('.bd-card') ? [s.borderTopLeftRadius, getComputedStyle(el).getPropertyValue('--r').trim(), parseFloat(getComputedStyle(el).fontSize)] : null }
      })
      if (seen.has(f.key) || f.key.startsWith('<body')) break
      seen.add(f.key)
      if (!f.ring && !f.within) bad.push(f.key)
      if (f.card) {
        const [radius, r, fs] = f.card
        expect(parseFloat(radius)).toBeCloseTo(r.endsWith('em') ? parseFloat(r) * fs : parseFloat(r), 1)
      }
    }
    expect(seen.size).toBeGreaterThan(10)
    expect([...seen].some(key => liveRows.some(row => row.id === key))).toBe(true)
    expect(bad).toEqual([])
  })
  test('K-8 a dimmed card is shown at full strength only while it has keyboard focus', async ({ page }) => {
    await open(page); await board(page)
    await page.evaluate(() => { st.S.f.model = ['codex']; st.fx.decorateAll() })
    await expect(card(page, '599')).toHaveClass(/dim/)
    await page.locator('#bd-tools button:not([disabled])').last().focus()
    await page.evaluate(() => { st.ctx.a11y.roving = '599'; document.querySelectorAll('#bd-content .bd-card[tabindex="0"]').forEach(el => { el.tabIndex = -1 }); document.querySelector('#bd-content .bd-card[data-id="599"]').tabIndex = 0 })
    expect(await tabToCard(page)).toBe('599')
    await expect(card(page, '599')).toHaveCSS('opacity', '1'); await expect(card(page, '599')).toHaveCSS('filter', 'none')
    await page.keyboard.press('ArrowDown')
    await expect(card(page, '599')).toHaveCSS('opacity', '0.26')
  })
})

test.describe('agent-state live region', () => {
  const region = page => page.locator('#bd-state-live')
  const record = page => page.evaluate(() => {
    window.__writes = []
    new MutationObserver(() => window.__writes.push(document.querySelector('#bd-state-live').textContent))
      .observe(document.querySelector('#bd-state-live'), { childList: true, characterData: true, subtree: true })
  })
  test('L-1/L-2 a state change is announced once; a reconnect snapshot is silent', async ({ page }) => {
    await open(page); await board(page)
    await expect(region(page)).toHaveAttribute('aria-live', 'polite'); await expect(region(page)).toHaveText('')
    await expect(region(page)).toHaveCount(1) // one region for agent states; first paint (a snapshot) wrote nothing
    await diff(page, 'a11y-state-error')
    await expect(region(page)).toHaveText('#599: Error')
    await expect(card(page, '599')).toHaveClass(/ag-stuck/)
    await record(page); await reconnect(page)
    await expect(card(page, '599')).toHaveClass(/ag-active/) // the snapshot did change the state back
    expect(await page.evaluate(() => window.__writes)).toEqual([])
    await expect(region(page)).toHaveText('#599: Error')
  })
  test('L-3 an unknown state is announced as unknown, never Running', async ({ page }) => {
    await open(page); await board(page)
    await diff(page, 'agent-state-null')
    await expect(region(page)).toHaveText('#599: state unknown')
  })
  test('L-4 five changes in one diff read three and a count', async ({ page }) => {
    await open(page); await board(page)
    await diff(page, 'a11y-five')
    await expect(region(page)).toHaveText('#599: Error; #600: Paused; #601: Running; and 2 more')
  })
  test('L-5 a diff that fails to apply announces nothing', async ({ page }) => {
    await open(page); await board(page); await record(page)
    const seq = await page.evaluate(() => st.ctx.resyncSeq)
    await diff(page, 'a11y-bad')
    // The hook resyncs after a failed apply; send the sentinel only once that snapshot has landed.
    await expect.poll(() => page.evaluate(seq => st.ctx.resyncSeq > seq && !st.ctx.proto.inFlight, seq)).toBe(true)
    await diff(page, 'a11y-state-error')
    await expect(region(page)).toHaveText('#599: Error')
    expect((await page.evaluate(() => window.__writes)).filter(text => text.includes('#604'))).toEqual([])
  })
  test('L-6 the same words twice are spoken twice', async ({ page }) => {
    await open(page); await board(page)
    await page.evaluate(() => st.announceState([['599', '#599: Error']]))
    await expect(region(page)).toHaveText('#599: Error')
    await record(page)
    await page.evaluate(() => st.announceState([['599', '#599: Error']]))
    await expect.poll(() => page.evaluate(() => window.__writes)).toEqual(['', '#599: Error'])
  })
})

test.describe('forced colours', () => {
  const look = (page, sel) => page.locator(sel).first().evaluate(el => {
    const s = getComputedStyle(el), i = getComputedStyle(el.querySelector('.bd-in'))
    return { opacity: s.opacity, filter: s.filter, outline: i.outlineStyle, border: i.borderTopWidth + ' ' + i.borderTopStyle }
  })
  for (const theme of ['dark', 'light']) test(`F-1 dimmed and chain-dimmed cards keep full opacity with a dashed cue (${theme})`, async ({ page }) => {
    await page.emulateMedia({ forcedColors: 'active' }); await open(page, 'live', '?trees=1'); await board(page)
    await page.evaluate(theme => document.documentElement.setAttribute('data-theme', theme), theme)
    await page.evaluate(() => { st.S.f.model = ['codex']; st.fx.decorateAll() })
    expect(await look(page, '#bd-now .bd-card.dim')).toMatchObject({ opacity: '1', filter: 'none', outline: 'dashed' })
    await page.evaluate(() => { st.S.f.model = []; st.fx.decorateAll() }); await reveal(page, 'plan')
    await page.evaluate(() => { const id = document.querySelector('#bd-sec-plan .bd-card').dataset.id; st.fx.setHover(id, document.querySelector(`#bd-content .bd-card[data-id="${id}"]`)) })
    expect(await look(page, '#bd-content .bd-card.hdim')).toMatchObject({ opacity: '1', filter: 'none', outline: 'dashed' })
  })
  test('F-2 agent states differ by border style and width; a highlight changes colour only', async ({ page }) => {
    await page.emulateMedia({ forcedColors: 'active' }); await open(page); await board(page)
    const borders = {}
    // live has no retrying agent; ag-queued is the class rowState gives one.
    await page.locator('#bd-now .bd-card.ag-active').last().evaluate(el => el.classList.replace('ag-active', 'ag-queued'))
    for (const ag of ['active', 'stuck', 'idle', 'queued']) borders[ag] = (await look(page, `#bd-now .bd-card.ag-${ag}`)).border
    expect(borders).toEqual({ active: '2px solid', stuck: '3px double', idle: '1px dotted', queued: '2px dashed' })
    await page.locator('#bd-now .bd-card.ag-stuck').first().evaluate(el => el.classList.add('hl'))
    expect((await look(page, '#bd-now .bd-card.ag-stuck.hl')).border).toBe('3px double')
  })
  for (const [theme, palette] of [['dark', 'gruvbox'], ['light', 'gruvbox'], ['light', 'aiur']]) test(`F-3 the progress fill is CanvasText (${theme} ${palette})`, async ({ page }) => {
    await page.emulateMedia({ forcedColors: 'active' }); await open(page); await board(page)
    await page.evaluate(([theme, palette]) => { document.documentElement.dataset.theme = theme; document.documentElement.dataset.palette = palette }, [theme, palette])
    const got = await page.locator('#bd-now .bd-card .bd-bar i').first().evaluate(el => {
      const probe = document.createElement('i'); probe.style.background = 'CanvasText'; document.body.appendChild(probe)
      const want = getComputedStyle(probe).backgroundColor; probe.remove()
      return [getComputedStyle(el).backgroundColor, want, getComputedStyle(el).forcedColorAdjust]
    })
    expect(got[0]).toBe(got[1]); expect(got[2]).toBe('none')
  })
  test('F-4 without forced colours the design values hold', async ({ page }) => {
    await open(page); await board(page)
    await page.evaluate(() => { st.S.f.model = ['codex']; st.fx.decorateAll() })
    expect(await look(page, '#bd-now .bd-card.dim')).toMatchObject({ opacity: '0.26', outline: 'none' })
    expect((await look(page, '#bd-now .bd-card.ag-stuck')).border).not.toBe('3px double')
  })
})

// axe with every rule on. A design colour that fails is not recoloured here: it is an `axe` allowlist entry
// (pending Kevin's sign-off, S-46) that removes only that rule's nodes on that selector, never the element.
async function auditWithAllowlist(page, results, entries, cell) {
  const used = new Set(), live = entries.filter(e => Object.entries(e.cells ?? {}).every(([k, v]) => cell[k] === v))
  for (const list of ['violations', 'incomplete']) {
    const kept = []
    for (const result of results[list]) {
      const hits = live.filter(e => e.rule === result.id)
      // One page call per rule: for each node, the first entry whose selector its element matches, or -1.
      const matches = hits.length ? await page.evaluate(([targets, sels]) => targets.map(target => {
        const el = document.querySelector(target)
        return el ? sels.findIndex(sel => el.matches(sel)) : -1
      }), [result.nodes.map(n => n.target.at(-1)), hits.map(e => e.selector)]) : result.nodes.map(() => -1)
      matches.forEach(i => { if (i >= 0) used.add(hits[i].id) })
      const nodes = result.nodes.filter((_, i) => matches[i] < 0)
      if (nodes.length) kept.push({ ...result, nodes })
    }
    results[list] = kept
  }
  return used
}
// Every rule stays on and every violation fails. axe files contrast it cannot compute under `incomplete`;
// on the board those are structural, not gaps: text over the cards' ::before backgrounds (pseudoContent),
// the ❶–❺ complexity glyphs (nonBmp), lane and wave labels over images (imgNode), cards overlapping
// neighbours (bgOverlap), one-letter monograms and lane initials that axe skips on purpose (shortTextContent),
// labels scrolled under the sticky lane header (elmPartiallyObscured) and the list's gradient rows
// (bgGradient, graded in dashboard_css_theme_test.exs). Any other reason still fails.
const UNGRADABLE = new Set(['bgGradient', 'pseudoContent', 'nonBmp', 'imgNode', 'bgOverlap', 'shortTextContent', 'elmPartiallyObscured'])
function expectBoardAuditClean(results) {
  expect(results.violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => n.target.join(' ')) }))).toEqual([])
  const ungraded = results.incomplete.filter(r => r.id === 'color-contrast').flatMap(r => r.nodes)
    .filter(n => !n.any.every(c => UNGRADABLE.has(c.data?.messageKey)))
  expect(ungraded.map(n => n.target.join(' ') + ' ' + n.any.map(c => c.data?.messageKey))).toEqual([])
}
// The matrix: Timeline in dark on every dataset (card kinds and source states differ by dataset), then the
// other views, the light theme and the open modal on live, which renders every card kind. A full scan of the
// board costs seconds; the browser shards run this suite on one worker, so this is the budget it fits.
const CELLS = [
  ...['live', 'dense', 'newrepo', 'noqueue', 'offline', 'unknowns'].map(dataset => ({ dataset, view: 'graph', theme: 'dark' })),
  { dataset: 'live', view: 'gantt', theme: 'dark' }, { dataset: 'live', view: 'list', theme: 'dark' },
  { dataset: 'live', view: 'graph', theme: 'light' }, { dataset: 'live', view: 'list', theme: 'light' },
  { dataset: 'live', view: 'modal', theme: 'dark' }, { dataset: 'live', view: 'modal', theme: 'light' },
]
for (const cell of CELLS) test(`X-1 axe: ${cell.dataset} ${cell.view} ${cell.theme}`, async ({ page }) => {
  test.slow()
  const entries = (await loadAllowlist()).filter(e => e.kind === 'axe' && e.spec === 'build-home-a11y.browser.spec.mjs')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  await open(page, cell.dataset, cell.view === 'modal' ? '' : '?view=' + cell.view)
  await expect(page.locator(cell.view === 'list' ? '.bd-list' : '#bd-content')).toHaveCount(1)
  await page.evaluate(theme => document.documentElement.setAttribute('data-theme', theme), cell.theme)
  if (cell.view === 'modal') {
    await card(page, '599').click(); await expect(page.locator('#tk-backdrop')).toHaveClass(/show/)
    await expect(page.locator('#tk-modal')).toHaveCSS('opacity', '1')
  }
  const results = await new AxeBuilder({ page }).include(cell.view === 'modal' ? '#tk-backdrop' : '#build-root').analyze()
  const used = await auditWithAllowlist(page, results, entries, cell)
  expectBoardAuditClean(results)
  // X-3: an entry for this cell whose selector is on screen here but which removed nothing is stale.
  const scope = cell.view === 'modal' ? '#tk-backdrop' : '#build-root'
  const present = await page.evaluate(([scope, sels]) => sels.map(sel => !!document.querySelector(scope).querySelector(sel)),
    [scope, entries.map(e => e.selector)])
  const stale = entries.filter((e, i) => present[i] && Object.entries(e.cells ?? {}).every(([k, v]) => cell[k] === v) && !used.has(e.id))
  expect(stale.map(e => e.id), 'stale axe allowlist entries').toEqual([])
})
test('X-2 an axe entry filters only its own rule: a nameless card on its selector still fails', async ({ page }) => {
  await open(page); await board(page); await reveal(page, 'plan')
  await page.locator('#bd-sec-plan .bd-card').first().evaluate(el => { el.removeAttribute('aria-label'); el.querySelector('.bd-in').textContent = '' })
  const entries = [{ id: 'probe', kind: 'axe', rule: 'color-contrast', selector: '.bd-card', cells: {} }]
  const results = await new AxeBuilder({ page }).include('#bd-sec-plan').analyze()
  await auditWithAllowlist(page, results, entries, { dataset: 'live', theme: 'dark' })
  expect(results.violations.map(v => v.id)).toContain('aria-command-name')
})
