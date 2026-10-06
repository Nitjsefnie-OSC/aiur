import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
const sha = file => createHash('sha256').update(readFileSync(new URL(file, root))).digest('hex');
const hashes = {
  'Bungee-Regular.woff2': '4513a7d68c82c053f363075a8aee249d60146f7c0bb7236cd27d721bffd16eeb',
  'SpaceGrotesk-Variable.woff2': 'cb48953e20ccd61690a20f1d910d333aa3a352e62ac18d3ffc4e0264a3c4aaa4',
  'JetBrainsMono-Variable.woff2': '11038e282dd7cb983dfc4e565017f37a91041c073c8929771fb6e64d27814396',
};
for (const [file, hash] of Object.entries(hashes)) {
  test(`${file} matches pinned Khala source and shipped copy`, () => {
    assert.equal(sha(`fonts/${file}`), hash);
    assert.equal(sha(`dist/fonts/${file}`), hash);
    assert.ok(readFileSync(new URL('assets/SOURCES.md', root), 'utf8').includes(hash));
  });
}
test('build ships every asset and license byte for byte', () => {
  for (const directory of ['assets', 'fonts']) {
    for (const file of readdirSync(new URL(`${directory}/`, root))) {
      assert.equal(sha(`dist/${directory}/${file}`), sha(`${directory}/${file}`));
    }
  }
});
test('optimized logo size budgets', () => {
  for (const [ext, limit] of [['png', 160000], ['webp', 90000]]) {
    assert.ok(statSync(new URL(`dist/assets/aiur-logo-512.${ext}`, root)).size <= limit);
  }
});
test('original logo and favicons match website sources', () => {
  for (const file of ['aiur-logo.png', 'favicon.ico', 'favicon-16x16.png', 'favicon-32x32.png',
    'apple-touch-icon.png', 'android-chrome-192x192.png', 'android-chrome-512x512.png', 'site.webmanifest']) {
    const source = file === 'aiur-logo.png' ? `assets/${file}` : file;
    const website = readFileSync(new URL(`../../website/public/${source}`, root));
    assert.deepEqual(readFileSync(new URL(`assets/${file}`, root)), website);
  }
});
