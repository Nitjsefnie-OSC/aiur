// Keep the entire composed viewport, including sticky layers and scrollbars, at
// the same raster origin. Header/usage height differs outside this ticket.
export async function alignBoard(pair) {
  for (const page of [pair.design, pair.product]) await page.evaluate(() => {
    window.scrollTo(0, 0); document.body.style.background = 'var(--bg)'
    const vp = document.querySelector('#bd-vp'), host = vp.parentElement, box = host.getBoundingClientRect()
    Object.assign(host.style, { position: 'fixed', left: Math.round(box.x) + 'px', top: '100px', width: box.width + 'px', zIndex: '9999' })
  })
}
export async function alignEtaMask(pair) {
  const widths = await Promise.all([pair.design, pair.product].map(page => page.locator('.bd-now-eta').evaluate(el => el.getBoundingClientRect().width)))
  for (const page of [pair.design, pair.product]) await page.locator('.bd-now-eta').evaluate((el, width) => { el.style.minWidth = width + 'px' }, Math.max(...widths))
}
