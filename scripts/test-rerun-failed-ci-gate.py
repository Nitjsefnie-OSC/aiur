#!/usr/bin/env python3
"""Ensure a body fix re-runs only a failed ci gate job."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name('rerun-failed-ci-gate.py')
SPEC = importlib.util.spec_from_file_location('rerun_ci_gate', MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RerunFailedCiGateTest(unittest.TestCase):
    def test_body_workflow_retries_only_after_validation_on_body_events(self):
        workflow = (Path(__file__).parents[1] / '.github/workflows/pr-body.yml').read_text()
        ci_workflow = (Path(__file__).parents[1] / '.github/workflows/ci.yml').read_text()
        self.assertIn('types: [opened, edited, synchronize, reopened]', workflow)
        self.assertIn('types: [opened, synchronize, reopened, ready_for_review]', ci_workflow)
        self.assertNotIn('types: [opened, edited, synchronize', ci_workflow)
        validation = workflow.index('name: Check PR body and local-test evidence')
        rerun = workflow.index('name: Re-run only a failed ci gate')
        self.assertLess(validation, rerun)
        self.assertRegex(workflow, r'actions:\s+write')
        self.assertIn('if: ${{ success() }}', workflow[rerun:])
        self.assertIn('scripts/rerun-failed-ci-gate.py', workflow[rerun:])
        self.assertIn('Require latest PR-body check', ci_workflow)

    def test_failed_gate_uses_single_job_rerun_endpoint(self):
        job = {'id': 71, 'head_sha': 'head', 'status': 'completed', 'conclusion': 'failure'}
        with patch.dict(os.environ, {'GITHUB_REPOSITORY': 'aiur-team/aiur'}):
            with patch.object(MODULE, 'api') as api:
                self.assertTrue(MODULE.rerun_if_failed(job))
        api.assert_called_once_with('repos/aiur-team/aiur/actions/jobs/71/rerun', 'POST')

    def test_current_head_run_and_gate_are_selected_before_rerun(self):
        runs_response = {
            'workflow_runs': [
                {'id': 1, 'name': 'ci', 'head_sha': 'old-head', 'run_number': 90},
                {'id': 2, 'name': 'ci', 'head_sha': 'current-head', 'run_number': 91},
                {'id': 3, 'name': 'pr body', 'head_sha': 'current-head', 'run_number': 92},
                {'id': 4, 'name': 'ci', 'head_sha': 'current-head', 'run_number': 90},
            ],
        }
        jobs_response = {
            'jobs': [
                {'id': 10, 'name': 'ci gate', 'head_sha': 'old-head',
                 'status': 'completed', 'conclusion': 'failure'},
                {'id': 20, 'name': 'ci gate', 'head_sha': 'current-head',
                 'status': 'completed', 'conclusion': 'failure'},
                {'id': 30, 'name': 'lint', 'head_sha': 'current-head',
                 'status': 'completed', 'conclusion': 'failure'},
                {'id': 21, 'name': 'ci gate', 'head_sha': 'current-head',
                 'status': 'completed', 'conclusion': 'failure'},
            ],
        }
        with patch.dict(os.environ, {
            'GITHUB_REPOSITORY': 'aiur-team/aiur', 'PR_HEAD': 'current-head',
        }):
            with patch.object(
                MODULE, 'api', side_effect=[runs_response, jobs_response, None],
            ) as api:
                selected_run = MODULE.current_ci_run()
                selected_job = MODULE.gate_job(selected_run)
                self.assertTrue(MODULE.rerun_if_failed(selected_job))

        self.assertEqual(selected_run['id'], 2)
        self.assertEqual(selected_job['id'], 21)
        self.assertEqual(api.call_args_list[0].args,
                         ('repos/aiur-team/aiur/actions/runs?head_sha=current-head&event=pull_request&per_page=100',))
        self.assertEqual(api.call_args_list[1].args,
                         ('repos/aiur-team/aiur/actions/runs/2/jobs?per_page=100',))
        self.assertEqual(api.call_args_list[2].args,
                         ('repos/aiur-team/aiur/actions/jobs/21/rerun', 'POST'))

    def test_successful_or_pending_gate_is_left_alone(self):
        for status, conclusion in [
            ('completed', 'success'), ('completed', 'cancelled'),
            ('in_progress', None), ('queued', None),
        ]:
            job = {'id': 72, 'head_sha': 'head', 'status': status, 'conclusion': conclusion}
            with patch.object(MODULE, 'api') as api:
                self.assertFalse(MODULE.rerun_if_failed(job))
            api.assert_not_called()


if __name__ == '__main__':
    unittest.main()
