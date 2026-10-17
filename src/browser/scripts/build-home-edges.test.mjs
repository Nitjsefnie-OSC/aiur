import test from 'node:test';
import assert from 'node:assert/strict';
import { edgeClass, edgeEmphasis, edgeGeometry } from '../../priv/static/build-home/edges.js';

const t = (dep_states, cue) => ({ dep_states, cue });

test('edgeClass maps server dep states', () => {
  assert.equal(edgeClass(t({ a: 'cleared' }), 'a'), 'ok');
  assert.equal(edgeClass(t({ a: 'blocking' }), 'a'), 'bl');
  assert.equal(edgeClass(t({ a: 'terminal_unsatisfied' }), 'a'), 'bad');
  assert.equal(edgeClass(t({ a: 'cleared' }), 'a', true), 'gh');
});
test('edgeClass keeps unknown edges neutral', () => {
  for (const row of [t({ a: 'unknown' }), t({ a: 'cyclic' }), t({}), t(undefined), t('x')]) assert.equal(edgeClass(row, 'a'), '');
});
test('edgeClass cue failure wins over blocking and unknown, not cleared', () => {
  assert.equal(edgeClass(t({ a: 'blocking' }, { failed: true }), 'a'), 'bad');
  assert.equal(edgeClass(t({ a: 'unknown' }, { blockedChain: true }), 'a'), 'bad');
  assert.equal(edgeClass(t({ a: 'cleared' }, { failed: true }), 'a'), 'ok');
});
test('edgeEmphasis', () => {
  const chain = new Set(['x', 'y']);
  assert.equal(edgeEmphasis(chain, 'x', 'y', false), ' hl');
  assert.equal(edgeEmphasis(chain, 'x', 'z', false), ' fade');
  assert.equal(edgeEmphasis(null, 'x', 'y', true), ' fade');
  assert.equal(edgeEmphasis(null, 'x', 'y', false), '');
});
const rect = (left, top, width, height) => ({ left, top, width, height, right: left + width, bottom: top + height });
test('edgeGeometry vertical, right and left cases', () => {
  const cr = rect(0, 0, 1000, 1000);
  assert.equal(edgeGeometry(rect(0, 0, 100, 50), rect(0, 100, 100, 50), cr).path, 'M50 50 C50 73.5 50 73.5 50 97');
  assert.match(edgeGeometry(rect(0, 0, 100, 50), rect(0, 100, 100, 50), cr).arrow, /^M46 91 L50 98 L54 91z$/);
  const r = edgeGeometry(rect(0, 0, 100, 50), rect(200, 10, 100, 50), cr);
  assert.equal(r.path, 'M100 25 C148.5 25 148.5 28 197 28');
  assert.equal(r.arrow, 'M191 24 L198 28 L191 32z');
  const l = edgeGeometry(rect(200, 0, 100, 50), rect(0, 10, 100, 50), cr);
  assert.equal(l.arrow, 'M109 24 L102 28 L109 32z');
});
