import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawnSync } from 'node:child_process'

const root = new URL('../', import.meta.url)
const check = fileURLToPath(new URL('./check-browser-smoke-shards.mjs', import.meta.url))
const packageJson = JSON.parse(readFileSync(new URL('src/browser/package.json', root), 'utf8'))
const runner = readFileSync(new URL('src/browser/scripts/run-browser-smoke-shard.mjs', root), 'utf8')
const scratch = mkdtempSync(join(tmpdir(), 'browser-smoke-shards-'))
try {
  const packagePath = join(scratch, 'package.json')
  const runnerPath = join(scratch, 'runner.mjs')
  writeFileSync(packagePath, JSON.stringify(packageJson))
  writeFileSync(runnerPath, runner)

  const valid = spawnSync(process.execPath, [check, packagePath, runnerPath], { encoding: 'utf8' })
  assert.equal(valid.status, 0, valid.stderr)
  assert.match(valid.stdout, /cover all \d+ test:core suites exactly once/)

  const omitted = runner.replace("'test:home-css-ci', ", '')
  assert.notEqual(omitted, runner, 'fixture must remove a real core suite')
  writeFileSync(runnerPath, omitted)
  const invalid = spawnSync(process.execPath, [check, packagePath, runnerPath], { encoding: 'utf8' })
  assert.equal(invalid.status, 1)
  assert.match(invalid.stderr, /Missing or duplicated suites: test:home-css-ci/)
} finally {
  rmSync(scratch, { recursive: true, force: true })
}

console.log('test-check-browser-smoke-shards: missing core suite fails with its name')
