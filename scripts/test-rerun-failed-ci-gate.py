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
