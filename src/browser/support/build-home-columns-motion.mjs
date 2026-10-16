export async function columnSequence(page, ctx, { click, cssMotion, state, scrollTo }) {
  const columnState = async () => { const { nodes } = await state(page, ctx); return { nodes: Object.fromEntries(Object.entries(nodes).filter(([key]) => key.startsWith('lane:') || key.startsWith('guide:'))) } }
  if (await page.locator('#bd-content').evaluate(el => el.classList.contains('flow'))) return { samples: [await columnState()], mode: 'flow' }
  // Month loads older days; week zoom preserves them without paging during measurement.
  if (await page.locator('.bd-cal [data-span="7"]').count()) await click(page, '.bd-cal [data-span="7"]')
  else await page.evaluate(async () => {
    const { S, ctx, fx, LH } = await import('/build-home/state.js')
    await (await import('/build-home/history.js')).ensureDays(30)
    S.span = 7; fx.relayout()
    ctx.vp.scrollTop = ctx.secs.hist.el.offsetTop + ctx.L.secs.hist.h - LH; fx.update()
  })
  await page.clock.runFor(16)
  await page.clock.runFor(704)
  const samples = [], initial = await page.locator('.bd-lane:not(.leave)').evaluateAll(nodes => nodes.map(el => el.title))
  await scrollTo(page, 270)
  let applyAt = null, removeAt = null, leaving = false, animation = {}
  for (let elapsed = 16; elapsed <= 800; elapsed += 16) {
    await page.clock.runFor(16)
    const lanes = await page.locator('.bd-lane').evaluateAll(nodes => nodes.map(el => ({ key: el.title, classes: [...el.classList].sort(), left: el.style.left, width: el.style.width })))
    const current = lanes.filter(lane => !lane.classes.includes('leave')).map(lane => lane.key), leave = lanes.some(lane => lane.classes.includes('leave'))
    if (applyAt === null && JSON.stringify(current) !== JSON.stringify(initial)) {
      applyAt = elapsed; animation = await cssMotion(page, '.bd-lanes', ctx)
    }
    if (leave) leaving = true
    if (leaving && !leave && removeAt === null) removeAt = elapsed
    samples.push(Object.fromEntries(lanes.map(lane => [lane.key, lane])))
  }
  if (applyAt === null || removeAt === null) throw new Error(`unreachable column enter/leave ${JSON.stringify({ initial, applyAt, removeAt, final: await page.locator('.bd-lane').allTextContents() })}`)
  return { samples, dom: await columnState(), applyAt, removeAt, animation }
}


// Match the toolbar fixture: isolate translucent chrome from unrelated shell geometry.
export async function normalizeColumnCapture(page) {
  await page.locator('.bd-lanes').evaluate(el => {
    const box = el.getBoundingClientRect()
    Object.assign(el.style, { position: 'fixed', left: Math.round(box.x) + 'px', top: '100px', width: Math.floor(box.width) + 'px', background: 'var(--bg)', zIndex: '9999', transform: 'translateZ(0)' })
  })
}
