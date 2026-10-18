import { spawnSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';
import { shardCommands } from './browser-suites.mjs';

// Discovered tests/build-home-*.browser.spec.mjs suites are added by hash; list only explicit scripts here.
// The key count is the shard count: it must match the browser matrix in .github/workflows/ci.yml.
// Balanced by recorded durations (browser-smoke-durations.mjs); check-browser-smoke-shards.mjs keeps each shard under 75% of budgetMs.
export const shards = {
  1: ["test:build-home-cards:4","test:build-home-cards:3","test:build-home","test:interaction","test:responsive","check:build-home-fixtures"],
  2: ["test:build-home-band-parity:3","test:build-home-render","test:units","test:shell","test:ticket-context","test:build-home-offline"],
  3: ["test:build-home-cards:2","test:build-home-span-parity","test:build-home-edges-parity","test:build-order","test:experiments","test:build-home-list-unit","test:admission"],
  4: ["test:build-home-columns","test:layout","test:meter-row","test:home-css-ci"],
  5: ["test:build-home-motion","test:build-home-edges","test:build-home-layout","test:build-queue","test:models-panel"],
  6: ["test:build-home-band-parity:1","test:build-home-cards:1","test:smoke","test:palette","test:harness"],
  7: ["test:build-home-band-motion","test:build-home-chains-parity:2","test:streamdeck","test:tokens","test:parity","test:time-brush","test:build-home-edges-unit"],
  8: ["test:build-home-tools","test:build-home-chains","test:build-home-now-band","test:build-home-span","test:build-home-assets","test:build-home-chains-unit","check:elk"],
  9: ["test:build-home-band-parity:4","test:design-parity","test:command-history","test:build-home-protocol","test:build-home-now-state"],
  10: ["test:build-home-usage","test:build-home-states-parity","test:shell-width","test:shell-chrome","test:performance","test:provider-meters"],
  11: ["test:build-home-band-parity:2","test:build-home-chains-parity:1","test:streamdeck-flow"],
  12: ["test:build-home-chains-parity:3","test:shell-parity","test:quota-panel"],
};

// Below the job's timeout-minutes, so a slow shard reports its slowest suites instead of being cancelled.
export const budgetMs = 19 * 60_000;
export { preflightSeconds, recordedSeconds } from './browser-smoke-durations.mjs';

function reportSlowest(heading, timings, limit = 10) {
  console.error(heading);
  for (const item of [...timings].sort((left, right) => right.durationMs - left.durationMs).slice(0, limit)) {
    console.error(`  ${item.command}: ${(item.durationMs / 1000).toFixed(1)}s`);
  }
}

function main() {
  const shard = Number(process.argv[2]);
  const plan = shardCommands(shards);
  if (!plan[shard]) throw new Error(`Unknown browser smoke shard: ${process.argv[2]}`);
  const timeoutMs = budgetMs;
  const deadline = performance.now() + timeoutMs;
  const preflight = spawnSync('npm', ['run', 'fixture:preflight'], { stdio: 'inherit' });
  if (preflight.error) throw preflight.error;
  if (preflight.status !== 0) process.exit(preflight.status ?? 1);
  const timings = [];
  for (const command of plan[shard]) {
    if (performance.now() >= deadline) {
      reportSlowest(`Browser smoke shard ${shard} reached its ${Math.round(timeoutMs / 1000)}s suite budget before ${command}; slowest completed suites:`, timings);
      process.exit(124);
    }
    const started = performance.now();
    const remainingMs = Math.max(1, Math.floor(deadline - started));
    const result = spawnSync('npm', ['run', ...command.split(' ')], { stdio: 'inherit', timeout: remainingMs });
    const durationMs = Math.round(performance.now() - started);
    timings.push({ command, durationMs });
    const timingFile = process.env.AIUR_BROWSER_TIMING_FILE;
    if (timingFile) appendFileSync(timingFile, `${JSON.stringify({ shard, script: command, durationMs })}\n`);
    if (result.error?.code === 'ETIMEDOUT') {
      reportSlowest(`Browser smoke shard ${shard} timed out in ${command}; slowest suites:`, timings);
      process.exit(124);
    }
    if (result.error) throw result.error;
    if (result.status !== 0) {
      reportSlowest(`Browser smoke shard ${shard} stopped at ${command}; slowest completed suites:`, timings);
      process.exit(result.status ?? 1);
    }
  }
  console.log(`Browser smoke shard ${shard} suite durations:`);
  for (const item of [...timings].sort((left, right) => right.durationMs - left.durationMs)) {
    console.log(`  ${item.command}: ${(item.durationMs / 1000).toFixed(1)}s`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
