import { spawnSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';

const shards = {
  1: ['test:home-css-ci', 'test:admission', 'check:elk', 'check:build-home-fixtures', 'test:build-home-protocol', 'test:build-home-now-state', 'test:harness', 'test:smoke', 'test:shell', 'test:shell-chrome', 'test:tokens', 'test:units', 'test:provider-meters', 'test:meter-row', 'test:models-panel', 'test:parity'],
  2: ['test:shell-width', 'test:command-history', 'test:build-order', 'test:build-queue', 'test:interaction', 'test:time-brush', 'test:performance', 'test:responsive', 'test:layout', 'test:ticket-context', 'test:shell-parity', 'test:streamdeck', 'test:quota-panel', 'test:streamdeck-flow', 'test:palette'],
  3: ['test:build-home-motion', 'test:build-home-offline', 'test:experiments'],
  4: ['test:design-parity', 'test:build-home-tools', 'test:build-home', 'test:build-home-span-parity'],
  5: ['test:build-home-assets', 'test:build-home-layout', 'test:build-home-render', 'test:build-home-span'],
};

const shard = Number(process.argv[2]);
if (!shards[shard]) throw new Error(`Unknown browser smoke shard: ${process.argv[2]}`);
const timeoutMs = 19 * 60_000;
const deadline = performance.now() + timeoutMs;
const preflight = spawnSync('npm', ['run', 'fixture:preflight'], { stdio: 'inherit' });
if (preflight.error) throw preflight.error;
if (preflight.status !== 0) process.exit(preflight.status ?? 1);
const timings = [];
for (const script of shards[shard]) {
  if (performance.now() >= deadline) {
    console.error(`Browser smoke shard ${shard} reached its ${Math.round(timeoutMs / 1000)}s suite budget before ${script}; slowest completed suites:`);
    for (const item of [...timings].sort((left, right) => right.durationMs - left.durationMs).slice(0, 10)) {
      console.error(`  ${item.script}: ${(item.durationMs / 1000).toFixed(1)}s`);
    }
    process.exit(124);
  }
  const started = performance.now();
  const remainingMs = Math.max(1, Math.floor(deadline - performance.now()));
  const result = spawnSync('npm', ['run', script], { stdio: 'inherit', timeout: remainingMs });
  const durationMs = Math.round(performance.now() - started);
  timings.push({ script, durationMs });
  const timingFile = process.env.AIUR_BROWSER_TIMING_FILE;
  if (timingFile) appendFileSync(timingFile, `${JSON.stringify({ shard, script, durationMs })}\n`);
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const timeout = result.error?.code === 'ETIMEDOUT';
    console.error(`Browser smoke shard ${shard} ${timeout ? 'timed out' : `stopped at ${script}`}; slowest completed suites:`);
    for (const item of [...timings].sort((left, right) => right.durationMs - left.durationMs).slice(0, 10)) {
      console.error(`  ${item.script}: ${(item.durationMs / 1000).toFixed(1)}s`);
    }
    process.exit(timeout ? 124 : result.status ?? 1);
  }
}
console.log(`Browser smoke shard ${shard} suite durations:`);
for (const item of [...timings].sort((left, right) => right.durationMs - left.durationMs)) {
  console.log(`  ${item.script}: ${(item.durationMs / 1000).toFixed(1)}s`);
}
