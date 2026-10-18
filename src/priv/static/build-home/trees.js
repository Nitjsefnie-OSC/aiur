import { S, ctx, fx, onReset, SPANS, LH } from './state.js';
import { chainOf, chainGaps, fitFrom, treeLayout, treeStatus, NW, NH } from './chains.js';
import { edgeClass } from './edges.js';
import { agentState } from './now-state.js';
import { ensureFrom, loadEarlier, H } from './history.js';
import { writeURL } from './url.js';
import { colKey } from './layout.js';
import { esc, $ } from './dom.js';
import { I } from './icons.js';

let fitToken = 0, hoverGen = 0, openRoot = null, returnFocus = null;
onReset(() => { fitToken++; hoverGen++; openRoot = null; returnFocus = null; });
const tab = () => ctx.content?.querySelector(':scope > .bd-lt');
const cardOf = id => [...ctx.R.values()].find(el => el.dataset.id === id) || ctx.L?.band.items.find(it => it.t.id === id)?.el;
const refText = t => fx.refText ? fx.refText(t) : t.num == null ? '—' : '#' + t.num;
function clearLater(ms) {
  const gen = ++hoverGen;
  ctx.life.later('tree-hover', ms, () => { if (gen === hoverGen && !ctx.lockId) setHover(null); });
}
export function onHover(e) {
  if (!S.trees || e.pointerType === 'touch' || ctx.lockId || ctx.content.classList.contains('scrolling')) return;
  hoverGen++;
  if (e.target.closest('.bd-lt')) return;
  const card = e.target.closest('.bd-card');
  if (card && !card.closest('.bd-now')) setHover(card.dataset.id, card);
  else clearLater(280);
}
export function onLeave() { if (!ctx.lockId) clearLater(200); }
export function toggleLock(b) {
  if (b.dataset.lt === 'lock') { if (ctx.lockId) unlock(); else if (ctx.hoverId) lockTree(ctx.hoverId); }
  else if (ctx.lockId) { if (b.dataset.lt === 'fit') fitTree(ctx.lockId); else openTree(ctx.lockId); }
}
export function setHover(id, el) {
  if (ctx.hoverId === id) return;
  ctx.hoverId = id; hoverGen++;
  const set = id ? chainOf(ctx.D, id) : null;
  ctx.R.forEach(card => {
    const cid = card.dataset.id;
    card.classList.toggle('hl', !!set && set.has(cid) && cid !== id);
    card.classList.toggle('hdim', !!set && !set.has(cid));
  });
  ctx.L?.band.items.forEach(it => it.el?.classList.toggle('hl', !!set && set.has(it.t.id)));
  const lt = tab();
  if (lt) {
    lt.classList.toggle('show', !!id && !!el);
    if (id && el) {
      const r = el.getBoundingClientRect(), c = ctx.content.getBoundingClientRect();
      lt.style.left = r.right - c.left - 1 + 'px';
      lt.style.top = r.top - c.top + Math.max(0, r.height / 2 - 14) + 'px';
    }
  }
  ctx.content?.classList.toggle('hovering', !!id);
  fx.drawEdges(true);
}
export function lockTree(id) {
  if (!ctx.D?.byId[id]) return;
  fitToken++; hoverGen++; ctx.lockId = id; ctx.hoverId = '~';
  setHover(id, cardOf(id));
  tab()?.classList.add('locked');
  tab()?.querySelector('[data-lt="lock"]').setAttribute('aria-pressed', 'true');
}
export function unlock() {
  fitToken++; ctx.lockId = null;
  tab()?.classList.remove('locked');
  tab()?.querySelector('[data-lt="lock"]').setAttribute('aria-pressed', 'false');
  setHover(null);
}
export function treeRange(id) {
  const set = chainOf(ctx.D, id); let a = Infinity, b = -Infinity;
  const add = (it, top) => { if (set.has(it.t.id)) { a = Math.min(a, top + it.y); b = Math.max(b, top + it.y + it.h); } };
  for (const s of ['hist', 'plan', 'nq']) ctx.L.secs[s].items.forEach(it => add(it, ctx.secs[s].el.offsetTop));
  ctx.L.band.items.forEach(it => add(it, ctx.bandEl.offsetTop));
  return [a, b];
}
export async function fitTree(id) {
  const token = ++fitToken, life = ctx.life;
  const current = () => token === fitToken && ctx.life === life && !life.disposed && ctx.content?.isConnected && !!ctx.D.byId[id];
  // Unknown dates cannot define a history range. Bound discovery per Fit action;
  // any remaining links stay visible as gaps instead of draining all history.
  let pages = 0;
  while (pages++ < 3 && current() && ctx.lockId === id && H.more && chainGaps(ctx.D, chainOf(ctx.D, id)).unloaded) {
    if (!await loadEarlier()) break;
  }
  if (!current() || ctx.lockId !== id) return;
  const from = fitFrom(ctx.D, id);
  if (from != null && S.histFrom > from) await ensureFrom(from, () => current() && ctx.lockId === id);
  if (!current() || ctx.lockId !== id) return;
  const room = ctx.vp.clientHeight - LH - 70;
  // Full relayout intentionally unlocks; preserve this Fit's token through that synchronous loop.
  for (const span of SPANS) {
    S.span = span; fx.relayout();
    const [a, b] = treeRange(id);
    if (b - a <= room) break;
  }
  const finishToken = fitToken;
  writeURL(); fx.renderTools();
  const [a, b] = treeRange(id);
  if (Number.isFinite(a) && Number.isFinite(b)) ctx.vp.scrollTo({ top: (a + b) / 2 - ctx.vp.clientHeight / 2 + LH / 2, behavior: 'instant' });
  fx.update();
  const finish = () => ctx.life === life && !life.disposed && fitToken === finishToken && ctx.content?.isConnected && ctx.D.byId[id];
  life.frame('fit-1', () => { if (finish()) life.frame('fit-2', () => { if (finish()) { fx.update(); lockTree(id); } }); });
}
export function reapply() {
  const id = ctx.lockId || ctx.hoverId;
  if (id) { ctx.hoverId = '~'; setHover(id, cardOf(id)); }
  if (openRoot) openTree(openRoot, { keep: true });
}
export function onTreesChanged(enabled) { if (!enabled) unlock(); }

export function openTree(id, { keep = false } = {}) {
  const host = $('#bd-tree', ctx.root);
  if (!host || !ctx.D.byId[id]) return;
  const oldScroller = $('.bd-tree-s', host), focused = document.activeElement?.closest('.bd-tn')?.dataset.id;
  const scroll = oldScroller && { left: oldScroller.scrollLeft, top: oldScroller.scrollTop };
  if (!keep && host.hidden) returnFocus = document.activeElement;
  openRoot = ctx.treeId = id;
  host.hidden = false; ctx.content.classList.add('treeview');
  host.setAttribute('role', 'dialog'); host.setAttribute('aria-modal', 'true'); host.setAttribute('aria-labelledby', 'bd-tree-t');
  const lay = treeLayout(ctx.D, id, host.clientWidth - 56, host.clientHeight - 96);
  const { ids, pos, natW, natH, sc, edges, levels } = lay;
  const edgeHTML = edges.map(e => {
    const cls = edgeClass(ctx.D.byId[e.id], e.dep);
    return '<path class="bd-e ' + cls + '" d="' + e.path + '"/><path class="bd-ea ' + cls + '" d="' + e.arrow + '"/>';
  }).join('');
  const nodes = ids.map(x => {
    const t = ctx.D.byId[x], p = pos[x], ag = t.sec === 'now' ? agentState(t.agent?.state) : null;
    const hue = (ctx.D.epics[colKey(t)] || ctx.D.epics.unsorted)?.hue;
    return '<button type="button" class="bd-tn ' + esc(t.sec) + (ag?.cls ? ' ag-' + ag.cls : '') + (t.status === 'failed' ? ' failed' : '') + (x === id ? ' sel' : '') + '" data-id="' + esc(x) + '" style="left:' + p.x + 'px;top:' + p.y + 'px;width:' + NW + 'px;height:' + NH + 'px;--h:' + (Number.isFinite(hue) ? hue : 0) + '"><span class="bd-tn1"><i></i><b>' + esc(refText(t)) + '</b><span>' + esc(t.title) + '</span></span><em>' + esc(treeStatus(t, fx.queueText)) + '</em></button>';
  }).join('');
  const gaps = chainGaps(ctx.D, new Set(ids)), count = gaps.unloaded + (gaps.missing ?? 0);
  let label = refText(ctx.D.byId[id]) + ' · ' + ids.length + ' tickets · ' + levels + ' levels';
  if (count) label += ' · ' + count + ' not on the board';
  if (gaps.missing === null) label += ' · links not yet known';
  host.innerHTML = '<div class="bd-tree-h"><b id="bd-tree-t">Dependency tree</b><span>' + esc(label) + '</span><button type="button" class="bd-tree-x" id="bd-tree-x">' + I.x + 'Close</button></div>' +
    '<div class="bd-tree-s"><div class="bd-tree-c" style="width:' + natW * sc + 'px;height:' + natH * sc + 'px"><div class="bd-tree-in" style="width:' + natW + 'px;height:' + natH + 'px;transform:scale(' + sc + ')"><svg class="bd-edges" aria-hidden="true" width="' + natW + '" height="' + natH + '">' + edgeHTML + '</svg>' + nodes + '</div></div></div>';
  const sw = $('.bd-tree-s', host), p0 = pos[id];
  sw.scrollLeft = keep && scroll ? scroll.left : Math.max(0, (p0.x + NW / 2) * sc - sw.clientWidth / 2);
  sw.scrollTop = keep && scroll ? scroll.top : Math.max(0, (p0.y + NH / 2) * sc - sw.clientHeight / 2);
  if (keep) {
    if (focused) ([...host.querySelectorAll('.bd-tn')].find(el => el.dataset.id === focused) || $('#bd-tree-x', host)).focus({ preventScroll: true });
    else if (document.activeElement === document.body) $('#bd-tree-x', host).focus({ preventScroll: true });
  } else $('#bd-tree-x', host).focus({ preventScroll: true });
}
export function closeTree() {
  const host = ctx.root && $('#bd-tree', ctx.root), wasOpen = openRoot !== null;
  openRoot = ctx.treeId = null;
  if (host) {
    host.hidden = true; host.innerHTML = '';
    for (const attr of ['role', 'aria-modal', 'aria-labelledby']) host.removeAttribute(attr);
  }
  ctx.content?.classList.remove('treeview');
  if (wasOpen) {
    const el = returnFocus?.isConnected && returnFocus.getClientRects().length ? returnFocus : ctx.vp;
    el?.focus({ preventScroll: true }); returnFocus = null;
  }
}
export function wireTrees() {
  const host = $('#bd-tree', ctx.root);
  ctx.bdTrees = ctx.root.dataset.bdTrees = 'ready';
  ctx.life.on(host, 'click', e => {
    e.stopPropagation();
    const node = e.target.closest('.bd-tn');
    if (node) { fx.openModal(ctx.D.byId[node.dataset.id], { origin: node }); return; }
    if (e.target.closest('#bd-tree-x') || !e.target.closest('.bd-tree-c')) closeTree();
  });
  ctx.life.on(host, 'keydown', e => {
    if (e.key !== 'Tab' || e.defaultPrevented || document.querySelector('#tk-backdrop.show')) return;
    const buttons = [...host.querySelectorAll('button')], first = buttons[0], last = buttons.at(-1);
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
  });
}
Object.assign(fx, { onHover, onLeave, toggleLock, setHover, lockTree, unlock, fitTree, treeRange,
  openTree, closeTree, reapply, onTreesChanged, wireTrees, chainOf: id => chainOf(ctx.D, id) });
