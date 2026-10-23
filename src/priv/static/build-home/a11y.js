// MP-E8-C12-T05: keyboard, names and announcements the design does not have. No pixels at rest.
import { S, ctx, fx, onReset } from './state.js';
import { agentText } from './agents.js';
import { agentState } from './now-state.js';
import { stText } from './list.js';
import { finite } from './cards.js';
import { colFor } from './render.js';

let pending = new Map();
const orders = new WeakMap();
onReset(() => { pending = new Map(); });

const unfiled = t => t.id.startsWith('pack:') && t.num === null;
const ref = t => unfiled(t) ? 'Not filed yet' : finite(t.num) === null ? 'Ticket number unknown' : '#' + t.num;

// One plain-text name per card; unknown values say "unknown", never 0 or a default.
export function cardLabel(t, D, snap, cls) {
  const parts = [unfiled(t) ? ref(t) + '. ' + t.title : ref(t) + ' ' + t.title];
  const agent = agentText(t, snap);
  if (t.sec === 'now') parts.push(agent);
  else parts.push(stText(t), ...(agent ? [agent] : []));
  if (t.sec === 'now') parts.push(finite(t.pct, 0, 100) === null ? 'progress unknown' : t.pct + '% done');
  const cx = finite(t.cx, 1, 5);
  parts.push(cx !== null && Number.isInteger(cx) ? 'Complexity ' + cx + ' of 5' : 'complexity unknown');
  // ponytail: D.children holds loaded rows only, so "unblocks" can undercount before older days load; the List view agrees.
  parts.push(t.deps.length + ' dependencies, unblocks ' + (D.children[t.id] || []).length);
  if (cls.contains('ghost')) parts.push('outside feature');
  if (cls.contains('also')) parts.push('also affects');
  if (cls.contains('dim')) parts.push('dimmed by filter');
  return parts.join('. ') + '.';
}

// What a screen reader should hear for one applied diff: agent state changes of rows that are, or were, live.
export function noteDiff(prev, next, msg) {
  const notes = [];
  for (const row of msg.upsert ?? []) {
    const before = prev?.byId[row.id], after = next.byId[row.id];
    if (!after || (before?.sec !== 'now' && after.sec !== 'now')) continue;
    if (after.sec === 'now') {
      if (before?.sec === 'now' && before.agent?.state === after.agent?.state) continue;
      const st = agentState(after.agent?.state);
      notes.push([after.id, ref(after) + ': ' + (st.cls ? st.label : 'state unknown')]);
    } else notes.push([after.id, ref(after) + ': ' + stText(after)]);
  }
  return notes;
}

function region() { return ctx.root?.querySelector('#bd-state-live'); }
function flush() {
  const el = region(), notes = [...pending.values()];
  pending = new Map();
  if (!el || !notes.length) return;
  const text = notes.slice(0, 3).join('; ') + (notes.length > 3 ? '; and ' + (notes.length - 3) + ' more' : '');
  if (el.textContent !== text) { el.textContent = text; return; }
  // The same words twice are a second change; clear first so the reader speaks them again.
  el.textContent = '';
  ctx.life.frame('a11y-live', () => { el.textContent = text; });
}
// Coalesce for 160 ms (interaction.js:390-399); a newer state of the same ticket replaces the older one.
export function announceState(notes) {
  if (!notes?.length || !ctx.life) return;
  for (const [id, text] of notes) { pending.delete(id); pending.set(id, text); }
  ctx.life.later('a11y-live', 160, flush);
}

const tops = () => ({ hist: ctx.secs.hist.el.offsetTop, now: ctx.secs.hist.el.offsetTop + ctx.L.secs.hist.h, plan: ctx.secs.plan.el.offsetTop, nq: ctx.secs.nq.el.offsetTop });
const elOf = it => it.sec === 'now' ? it.el : ctx.R.get(it.sec + ':' + it.t.id);
// Board order: history (top), the live band, plan, not queued; inside a section by y, then column, then lane.
export function readingOrder(L = ctx.L) {
  if (!L) return [];
  if (orders.has(L)) return orders.get(L);
  const x = it => (colFor(it)?.x ?? 0) + (it.lane || 0);
  const seen = new Set(), order = [];
  for (const items of [L.secs.hist.items, L.band.items, L.secs.plan.items, L.secs.nq.items]) {
    for (const it of [...items].sort((a, b) => a.y - b.y || x(a) - x(b))) {
      if (!seen.has(it.t.id)) { seen.add(it.t.id); order.push(it); }
    }
  }
  orders.set(L, order);
  return order;
}

// One Tab stop on the board: the focused card, else the first card at or below the scroll top.
export function syncRoving() {
  if (!ctx.L || !ctx.content) return;
  const active = document.activeElement?.closest?.('.bd-card');
  let id = active && ctx.content.contains(active) ? active.dataset.id : null;
  if (!id) {
    const top = ctx.vp.scrollTop, at = tops(), order = readingOrder();
    id = (order.find(it => at[it.sec] + it.y + it.h > top && elOf(it)) ?? order.find(elOf))?.t.id ?? null;
  }
  ctx.a11y.roving = id;
  ctx.content.querySelectorAll('.bd-card[tabindex="0"]').forEach(el => { if (el.dataset.id !== id) el.tabIndex = -1; });
  const it = id && readingOrder().find(item => item.t.id === id), el = it && elOf(it);
  if (el) el.tabIndex = 0;
}

function moveTo(it) {
  const vp = ctx.vp, top = tops()[it.sec] + it.y;
  if (!elOf(it) || top < vp.scrollTop || top + it.h > vp.scrollTop + vp.clientHeight) {
    vp.scrollTop = top - vp.clientHeight / 3; fx.update();
  }
  const el = elOf(it);
  if (!el) return;
  ctx.a11y.focusId = it.t.id; el.focus({ preventScroll: true }); syncRoving();
}
const STEP = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 };
export function onCardKey(e) {
  const card = e.target.closest?.('.bd-card');
  if (!card || e.target !== card || e.altKey || e.ctrlKey || e.metaKey) return false;
  const order = readingOrder(), i = order.findIndex(it => it.t.id === card.dataset.id);
  if (e.key === ' ') {
    e.preventDefault();
    if (!S.trees) card.click(); else if (ctx.lockId) fx.unlock(); else fx.lockTree(card.dataset.id);
    return true;
  }
  if (e.key === 'Enter') { e.preventDefault(); card.click(); return true; }
  let target = null;
  if (e.key === 'Home') target = order[0];
  else if (e.key === 'End') target = order.at(-1);
  else if (STEP[e.key] && i >= 0) target = order[i + STEP[e.key]];
  else if (!STEP[e.key]) return false;
  e.preventDefault();
  if (target) moveTo(target);
  return true;
}
// Keyboard focus is hover for chains: the pointer path's own guards (S.trees, scrolling, lock, band) apply.
// A tap or click also focuses the card but is not :focus-visible, so touch keeps its no-hover rule.
export function onCardFocusIn(e) {
  if (!e.target.matches?.('.bd-card')) return;
  ctx.a11y.focusId = e.target.dataset.id;
  if (e.target.matches(':focus-visible')) fx.onHover(e);
}
export function onCardFocusOut(e) { if (!e.relatedTarget?.closest?.('.bd-card')) fx.onLeave(); }

