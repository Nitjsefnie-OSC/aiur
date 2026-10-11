import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { createRequire } from 'node:module'
import test from 'node:test'

// Playwright pins this YAML parser; use it without adding a test-only dependency.
const { yaml } = createRequire(import.meta.url)('../node_modules/playwright-core/lib/utilsBundle.js')
const root = new URL('../../../', import.meta.url)
const read = path => readFileSync(new URL(path, root), 'utf8')
const workflow = yaml.parse(read('.github/workflows/ci.yml'))
const home = yaml.parse(read('.github/actions/verify-home-css/action.yml'))
const scripts = JSON.parse(read('src/browser/package.json')).scripts

test('required browser gate rejects failures, cancellations and skipped child jobs', () => {
  const gate = Object.values(workflow.jobs).find(job => job.name === 'browser harness')
  assert.deepEqual(gate.needs, ['changes', 'browser', 'home-css'])
  assert.match(gate.if, /always\(\)/)
  const step = gate.steps.find(step => step.name === 'Require both browser suites')
  assert.equal(step.env.BROWSER_RESULT, '${{ needs.browser.result }}')
  assert.equal(step.env.HOME_CSS_RESULT, '${{ needs.home-css.result }}')
  for (const browser of ['success', 'failure', 'cancelled', 'skipped']) {
    for (const css of ['success', 'failure', 'cancelled', 'skipped']) {
      const result = spawnSync('bash', ['-c', step.run], {
        env: { ...process.env, BROWSER_RESULT: browser, HOME_CSS_RESULT: css }
      })
      assert.equal(result.status === 0, browser === 'success' && css === 'success', `${browser}/${css}`)
    }
  }
})

test('home matrix has an independent deadline and stays in the local full suite', () => {
  assert.equal(workflow.jobs.browser['timeout-minutes'], 30)
  assert.equal(workflow.jobs['home-css']['timeout-minutes'], 25)
  assert.equal(workflow.jobs['home-css'].steps.at(-1).uses, './.github/actions/verify-home-css')
  assert.equal(home.runs.steps.find(step => step.name === 'Run complete home CSS matrix').run,
    'npm run fixture:preflight && npm run test:home-css')
  assert.equal(home.runs.steps.at(-1).if, '${{ always() }}')
  assert.equal(scripts.test, 'npm run test:core && npm run test:home-css')
  assert.ok(!scripts['test:core'].includes('npm run test:home-css'))
  assert.match(scripts['test:home-css'], /home-css-census\.browser\.spec\.mjs tests\/home-css-parity\.browser\.spec\.mjs/)
})
