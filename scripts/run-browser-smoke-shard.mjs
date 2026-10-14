import { spawnSync } from 'node:child_process';

const shards = {
  1: ['liveview-smoke.spec.mjs', 'build-home-assets.browser.spec.mjs', 'route-shell.browser.spec.mjs', 'shell-history-contrast.browser.spec.mjs', 'shell-chrome.browser.spec.mjs', 'shell-content-width.browser.spec.mjs', 'command-history.browser.spec.mjs', 'build-queue.browser.spec.mjs', 'build-order-route.browser.spec.mjs', 'optimistic-analytics.browser.spec.mjs', 'build-order-interaction.browser.spec.mjs', 'time-brush.browser.spec.mjs'],
  2: ['build-order-performance.browser.spec.mjs', 'build-order-responsive.browser.spec.mjs', 'layout-worker.browser.spec.mjs', 'dom-svg-layout-adapter.browser.spec.mjs', 'ticket-context.browser.spec.mjs', 'units.browser.spec.mjs', 'units-voice.browser.spec.mjs', 'units-tickets.browser.spec.mjs', 'provider_meters.browser.spec.mjs', 'meter-row.browser.spec.mjs', 'models-panel.browser.spec.mjs'],
  3: ['quota-panel.browser.spec.mjs', 'parity-composition.browser.spec.mjs', 'streamdeck-emulator-dials-keys.browser.spec.mjs', 'streamdeck-emulator-modes-paging.browser.spec.mjs', 'streamdeck-emulator-surface.browser.spec.mjs', 'streamdeck-operator-flow.browser.spec.mjs', 'design-parity-harness.browser.spec.mjs', 'palette-probe.browser.spec.mjs', 'build-home-tokens.browser.spec.mjs', 'shell-design-parity.browser.spec.mjs', 'build-home-shell.browser.spec.mjs', 'build-home-loading-parity.browser.spec.mjs', 'build-home-motion.browser.spec.mjs', 'visual-shell.browser.spec.mjs'],
};

const shard = Number(process.argv[2]);
if (!shards[shard]) throw new Error(`Unknown browser smoke shard: ${process.argv[2]}`);
const result = spawnSync('node', ['scripts/run-browser-tests.mjs', ...shards[shard].map((file) => `tests/${file}`)], { stdio: 'inherit' });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
