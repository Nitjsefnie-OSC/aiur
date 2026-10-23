import { test, expect } from '@playwright/test'
import { PARITY_VIEWPORTS, expectDesignParity, parityContextOptions, loadAllowlist, openDesign, openProduct } from '../support/design-parity.mjs'
import { readFile } from 'node:fs/promises'
import { compareRegion } from '../support/build-home-region-parity.mjs'

// Keep the design on live while every product context selects unfiled from the start.
// The fixture dataset is process-global, so parallel cells must never select live.
async function openUnfiledPair(browser,cell) {
  const options=parityContextOptions(cell)
  const contexts=[await browser.newContext(options),await browser.newContext({...options,baseURL:test.info().project.use.baseURL})]
  const pair={design:await contexts[0].newPage(),product:await contexts[1].newPage(),cell,close:()=>Promise.all(contexts.map(context=>context.close()))}
  try {
    pair.allowlist=await loadAllowlist()
    const root=test.info().project.metadata.agentAssets
    if(root) for(const name of ['modal/frame.js','modal/header.js','modal/focus.js','modal/doc.js','modal/conversation.js','modal/conversation-events.js','modal/conversation-items.js','modal/conversation-footer.js','hook.js','home.css','home/19-modal-doc.css']) {
      await pair.product.route('**/build-home/'+name,async route=>route.fulfill({body:await readFile(root+'/'+name,'utf8'),contentType:name.endsWith('.css')?'text/css':'text/javascript'}))
    }
    await openDesign(pair.design,cell)
    await openProduct(pair.product,cell,{dataset:'unfiled',productPending:true})
    return pair
  } catch(error) {await pair.close();throw error}
}

// Full-surface captures retain their failure PNGs without accumulating per-action DOM traces.
test.use({ trace: 'off' })
test.setTimeout(180_000)
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark', 'light']) for (const palette of ['aiur', 'gruvbox']) {
  test(`unfiled modal elements ${viewport.viewport.width} ${theme} ${palette}`, async ({ browser }) => {
    const pair = await openUnfiledPair(browser, { ...viewport, theme, palette, dataset: 'live' })
    try {
      await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-generation', /\d+/)
      const row = await pair.product.evaluate(async () => (await import('/build-home/state.js')).ctx.D.plan.find(t => t.src?.kind === 'pack'))
      expect(row.id).toBe('pack:build-plan/BP-645')
      await pair.design.evaluate(() => window.AiurBuild.open('AIUR-645'))
      await pair.product.evaluate(async id => (await import('/build-home/modal/frame.js')).openById(id), row.id)
      for (const side of ['design', 'product']) await pair[side].locator('#tk-modal').evaluate(el => el.getAnimations().forEach(a => a.finish()))
      for (const selector of ['.bm-st', '.bm-src', '#tk-head .bm-ib[data-a="none"]']) {
        await compareRegion(pair, { name: `unfiled.${viewport.viewport.width}.${theme}.${palette}.${selector}`, region: selector })
      }
      for (const side of ['design', 'product']) await pair[side].locator('#tk-head .bm-ib[data-a="none"]').hover()
      await compareRegion(pair, { name: `unfiled.docs-hover.${viewport.viewport.width}.${theme}.${palette}`, region: '#tk-head .bm-ib[data-a="none"]' })
    } finally { await pair.close() }
  })
}

// Expose original reference operations; never replace their rendering or data.
const designSource = await (await import('node:fs/promises')).readFile(new URL('../../test/fixtures/build_home/design-source/assets/build.js', import.meta.url), 'utf8')
const reference = designSource.replace('  window.AiurBuild = {', `  window.unfiledParity = {
  scroll(id) { const it = L.secs.plan.items.find(it => it.t.id === id); scrollVP(secs.plan.el.offsetTop + it.y - 160, false); update(true); },
  tree: openTree,
  freeze() {S.ready=false;snapping=true;},
};\n  window.AiurBuild = {`)
// Mask overlays cover equal rectangles without changing the identity slot's layout.
async function maskRow(pair,region,slots) {
  if(region.includes('.bd-tn')) {
    const entry=pair.allowlist.find(entry=>entry.id==='unfiled-tree-reference-width')
    expect(entry).toMatchObject({kind:'property',cells:{dataset:'live'},approval:{status:'pending-sign-off'}})
    await expect.poll(()=>pair.product.locator(region).locator('b').evaluate(el=>parseFloat(getComputedStyle(el).width))).toBeGreaterThan(0)
    const width=await pair.product.locator(region).locator('b').evaluate(el=>{
      const transform=getComputedStyle(el.closest('.bd-tree-in')).transform
      const scale=transform==='none'?1:new DOMMatrix(transform).a
      return Math.round((parseFloat(getComputedStyle(el).width)||el.getBoundingClientRect().width/scale)*64)/64
    })
    await pair.design.locator(region).locator('b').evaluate((el,width)=>{el.style.width=width+'px';el.style.overflow='hidden'},width)
  }
  for (const slot of slots) {
    const nodes = [pair.design,pair.product].map(page => page.locator(region).locator(slot))
    if(region.includes('.bd-tn')) for(const node of nodes) await expect.poll(()=>node.evaluate(el=>{const b=el.getBoundingClientRect();return b.width>0&&b.height>0})).toBe(true)
    const boxes = await Promise.all(nodes.map(node => node.evaluate(el => {const b=el.getBoundingClientRect();return {width:b.width,height:b.height}})))
    const size = {width:Math.max(...boxes.map(b=>b.width)),height:Math.max(...boxes.map(b=>b.height))}
    for (const node of nodes) await node.evaluate((el,size) => {
      el.querySelector('[data-unfiled-mask]')?.remove()
      const mask=document.createElement('span');mask.dataset.unfiledMask=''
      const style=getComputedStyle(el),ancestor=el.closest('.bd-tree-in')
      const transform=ancestor?getComputedStyle(ancestor).transform:'none',scale=transform==='none'?1:new DOMMatrix(transform).a
      const box=el.getBoundingClientRect(),cardIcon=el.matches('.bd-id')?el.previousElementSibling:null,title=el.matches('.bd-tn1 b')?el.nextElementSibling:null,dot=title?el.previousElementSibling:null
      const rasterMargin=title?Math.min(1/devicePixelRatio,Math.max(0,title.getBoundingClientRect().left-box.right)):0
      const rasterLeft=cardIcon?1/devicePixelRatio:dot?Math.min(1/devicePixelRatio,Math.max(0,(box.left-dot.getBoundingClientRect().right)/2)):0
      el.style.position='relative'
      Object.assign(mask.style,{position:'absolute',left:(-parseFloat(style.borderLeftWidth||0)-rasterLeft/scale)+'px',top:-parseFloat(style.borderTopWidth||0)+'px',width:(size.width+rasterMargin+rasterLeft)/scale+'px',height:size.height/scale+'px',pointerEvents:'none'})
      el.append(mask)
      const measured=mask.getBoundingClientRect()
      if(title && !(measured.width>0&&measured.height>0)) throw new Error('Identity mask has empty geometry')
      if(cardIcon && mask.getBoundingClientRect().left<=cardIcon.getBoundingClientRect().right) throw new Error('Identity mask overlaps the unmasked card icon')
      if(title && mask.getBoundingClientRect().right>=title.getBoundingClientRect().left) throw new Error('Reference mask overlaps the unmasked title')
      if(dot && mask.getBoundingClientRect().left<=dot.getBoundingClientRect().right) throw new Error('Reference mask overlaps the unmasked status dot')
    },size)
  }
}
async function maskVisible(pair,kind,slots) {
  for (const num of ids) {
    const region=`:is(.${kind}[data-id="AIUR-${num}"],.${kind}[data-id="pack:build-plan/BP-${num}"])`
    const counts=await Promise.all([pair.design,pair.product].map(page=>page.locator(region).count()))
    expect(counts[1],`matching rendered row ${num}`).toBe(counts[0])
    if(counts[0]) await maskRow(pair,region,slots)
  }
}
const ids = Array.from({length:16}, (_,i) => 645+i)
for (const viewport of PARITY_VIEWPORTS) for (const theme of ['dark','light']) for (const palette of ['aiur','gruvbox']) {
  test(`unfiled row cells ${viewport.viewport.width} ${theme} ${palette}`, async ({browser}) => {
    test.setTimeout(600_000)
    const pair = await openUnfiledPair(browser,{...viewport,theme,palette,dataset:'live'})
    try {
      await pair.design.route('**/assets/build.js*',route => route.fulfill({body:reference,contentType:'text/javascript'}))
      await pair.design.reload()
      await expect.poll(() => pair.design.evaluate(() => !!window.unfiledParity && !!document.querySelector('.bd-card'))).toBe(true)
      await expect(pair.product.locator('#build-root')).toHaveAttribute('data-build-generation',/\d+/)
      for (const page of [pair.design,pair.product]) await expect(page.locator('.bd-content')).not.toHaveClass(/\bscrolling\b/)
      await pair.design.evaluate(() => window.unfiledParity.freeze())
      await pair.product.evaluate(async () => {const {S,ctx}=await import('/build-home/state.js');S.ready=false;ctx.snapping=true})
      // The sticky live band is unrelated to isolated planned-card pixels.
      for (const page of [pair.design,pair.product]) await page.locator('#bd-now').evaluate(el => {el.style.visibility='hidden'})
      const surfaces = [
        {kind:'bd-card',view:'graph',region:'#bd-vp',slots:['.bd-id','.bd-status > span:first-child']},
        {kind:'lr',view:'list',region:'#bd-vp',slots:['.c-id','.c-pg .lr-mu','.c-st .lst']},
        {kind:'bd-tn',view:'graph',region:'.bd-tree-s',slots:['b','em']},
      ]
      for (const surface of surfaces) {
        for (const page of [pair.design,pair.product]) await page.locator('[data-v="'+surface.view+'"]').click()
        if(surface.kind!=='bd-tn') for(const page of [pair.design,pair.product]) await page.locator('#bd-vp').evaluate(el=>el.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'}))
        if(surface.kind==='bd-tn') await pair.product.evaluate(async()=>{
          const {H,loadEarlier}=await import('/build-home/history.js')
          for(let page=0;H.more&&page<100;page++) if(!await loadEarlier(31)) throw new Error('History parity intake failed')
          if(H.more) throw new Error('History parity intake remained incomplete')
        })
        if(surface.kind==='bd-card') for(const page of [pair.design,pair.product]) await page.locator('#bd-now').evaluate(el=>{el.style.visibility='hidden'})
        const covered = new Set()
        for (const num of ids) {
          if (covered.has(num)) continue
          if (surface.kind === 'bd-card') {
            await pair.design.evaluate(num => window.unfiledParity.scroll('AIUR-'+num),num)
            await pair.product.evaluate(async num => {
              const {ctx,fx}=await import('/build-home/state.js')
              const it=ctx.L.secs.plan.items.find(it=>it.t.id==='pack:build-plan/BP-'+num)
              fx.scrollVP(ctx.secs.plan.el.offsetTop+it.y-160,false);fx.update()
            },num)
          } else if (surface.kind === 'lr') {
            for (const [index,page] of [pair.design,pair.product].entries()) await page.locator('.lr[data-id="'+(index?'pack:build-plan/BP-':'AIUR-')+num+'"]').evaluate(el=>{const vp=document.querySelector('#bd-vp');vp.scrollTop+=el.getBoundingClientRect().top-vp.getBoundingClientRect().top-70})
          } else {
            await pair.design.evaluate(num=>window.unfiledParity.tree('AIUR-'+num),num)
            await pair.product.evaluate(async num=>(await import('/build-home/trees.js')).openTree('pack:build-plan/BP-'+num),num)
            for(const page of [pair.design,pair.product]) {
              await page.locator('.bd-tree-s').evaluate(el=>el.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'}))
              // History intake schedules a trailing relayout which rebuilds tree nodes.
              await page.waitForTimeout(350)
            }
          }
          await maskVisible(pair,surface.kind,surface.slots)
          const visible = await Promise.all([pair.design,pair.product].map(page=>page.locator(surface.region).evaluate((root,kind)=>{
            const box=root.getBoundingClientRect()
            const top=Math.max(0,box.top),left=Math.max(0,box.left)
            const viewport={top,left,bottom:top+Math.floor(Math.min(innerHeight,box.bottom)-top),right:left+Math.floor(Math.min(innerWidth,box.right)-left)}
            return [...root.querySelectorAll('.'+kind+'[data-id]')].filter(el=>{
              const b=el.getBoundingClientRect()
              const inside=b=>b.top>=viewport.top+(kind==='bd-card'?46:0) && b.bottom<=viewport.bottom && b.left>=viewport.left && b.right<=viewport.right
              if(kind!=='lr') return inside(b)
              const style=getComputedStyle(el)
              const content={top:b.top+parseFloat(style.borderTopWidth),bottom:b.bottom-parseFloat(style.borderBottomWidth),left:b.left+parseFloat(style.paddingLeft),right:b.right-parseFloat(style.paddingRight)}
              const children=[...el.querySelectorAll(':scope > [role="cell"], .c-id > *, .c-st > *')].map(child=>child.getBoundingClientRect()).filter(box=>box.width&&box.height)
              return inside(content) && children.every(inside)
            }).map(el=>Number(el.dataset.id.replace(/^(AIUR-|pack:build-plan\/BP-)/,''))).filter(n=>n>=645&&n<=660).sort((a,b)=>a-b)
          },surface.kind)))
          expect(visible[1],surface.kind+' visible identities').toEqual(visible[0])
          expect(visible[1],surface.kind+' requested row content is fully captured').toContain(num)
          if(surface.kind==='bd-tn') for(const page of [pair.design,pair.product]) {
            expect(await page.locator('.bd-tn').evaluateAll((rows,ids)=>rows.filter(row=>ids.some(id=>row.dataset.id==='AIUR-'+id||row.dataset.id==='pack:build-plan/BP-'+id)).every(row=>[...row.querySelectorAll('b,em')].every(owned=>{
              const mask=owned.querySelector('[data-unfiled-mask]')
              if(!mask) return false
              const a=owned.getBoundingClientRect(),b=mask.getBoundingClientRect()
              return b.width>0&&b.height>0&&Math.min(a.right,b.right)>Math.max(a.left,b.left)&&Math.min(a.bottom,b.bottom)>Math.max(a.top,b.top)
            })),ids),'tree identity masks remain present with positive owned intersection').toBe(true)
          }
          await expectDesignParity(pair,{name:`unfiled-${viewport.viewport.width}-${theme}-${palette}-${surface.kind}-${num}`,region:surface.region,preserveAnimations:true,regionCapture:surface.kind==='bd-tn'?'contained':'visible'})
          visible[1].forEach(id=>covered.add(id))
        }
        expect([...covered].sort((a,b)=>a-b),surface.kind+' captures cover every unfiled row').toEqual(ids)
        if(surface.kind==='bd-tn') for(const page of [pair.design,pair.product]) {await page.locator('#bd-tree-x').evaluate(el=>el.click());await page.evaluate(()=>window.scrollTo(0,0))}
      }
    } finally {await pair.close()}
  })
}
