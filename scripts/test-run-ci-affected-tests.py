#!/usr/bin/env python3
"""Exercise the selector runner with a hermetic Mix executable."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('run-ci-affected-tests.py')


class AffectedRunnerTest(unittest.TestCase):
    def run_selection(self, selection, status=0):
        with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as scratch:
            root = Path(scratch)
            mix = root / 'mix'
            mix.write_text('''#!/usr/bin/env python3
import json, os, sys
if sys.argv[1] == 'aiur.affected_tests':
    assert sys.argv[2] == 'base-sha'
    print(os.environ['SELECTION'])
else:
    with open(os.environ['CALLS'], 'a') as out:
        out.write(json.dumps(sys.argv[1:]) + '\\n')
    sys.exit(int(os.environ['TEST_STATUS']))
''')
            mix.chmod(0o755)
            calls = root / 'calls'
            summary = root / 'summary'
            result = subprocess.run(['python3', str(SCRIPT), 'base-sha'], capture_output=True,
                                    env=dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                                             SELECTION=selection, CALLS=str(calls), TEST_STATUS=str(status),
                                             GITHUB_STEP_SUMMARY=str(summary)))
            self.last_stderr = result.stderr
            self.assertNotIn(b"can't open file", result.stderr)
            invoked = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            summary_text = summary.read_text() if summary.exists() else ''
            return result.returncode, invoked, result.stdout.decode(), summary_text

    def test_runs_selected_paths_without_shell_evaluation(self):
        self.assertEqual(self.run_selection("cd src && mise exec -- mix test --max-cases 4 'test/a test.exs' 'test/$(bad)_test.exs'"),
                         (0, [['test', '--max-cases', '4', 'test/a test.exs', 'test/$(bad)_test.exs']],
                          "cd src && mise exec -- mix test --max-cases 4 'test/a test.exs' 'test/$(bad)_test.exs'\n\n", ''))

    def test_unsafe_selection_defers_full_suite_to_merge_queue(self):
        reason = 'changed files include test support; changed paths: src/test/support/helper.exs'
        status, calls, output, summary = self.run_selection(
            f'# full suite recommended: {reason}\ncd src && mise exec -- make ci'
        )
        self.assertEqual(status, 0)
        self.assertEqual(calls, [])
        self.assertIn(f'::notice::Unsafe affected selection deferred to full CI in the merge queue: {reason}', output)
        self.assertIn(reason, summary)

    def test_no_tests_does_not_run_test_suite(self):
        self.assertEqual(self.run_selection('# no affected test files detected for the documentation-only change'),
                         (0, [], '# no affected test files detected for the documentation-only change\n\n', ''))

    def test_failure_is_not_reported_as_success(self):
        self.assertNotEqual(self.run_selection('cd src && mise exec -- mix test --max-cases 4 test/a_test.exs', 1)[0], 0)

    def test_unrecognized_output_fails_closed(self):
        for value in ['unexpected', 'cd src && mise exec -- echo success']:
            self.assertNotEqual(self.run_selection(value)[0], 0)


if __name__ == '__main__':
    unittest.main()
