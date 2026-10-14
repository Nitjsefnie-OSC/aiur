#!/usr/bin/env python3
"""Regression checks for conflict-prone shared list files."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('hot_list_format', REPO / 'scripts/check-hot-list-format.py')
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class SharedListMergeTest(unittest.TestCase):
    def test_union_merge_of_concurrent_allowlist_additions_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'scripts/components/allowlist/kernel.tsv'
            path.parent.mkdir(parents=True)
            path.write_text('# rule\ttarget_module\treason\n')
            right = root / 'right.tsv'
            right.write_text('# rule\ttarget_module\treason\nR-private\tB.Right\t#101 right\n')
            path.write_text('# rule\ttarget_module\treason\nR-private\tA.Left\t#100 left\n')
            result = subprocess.run(
                ['git', 'merge-file', '-p', str(path), str(path), str(right)],
                capture_output=True, text=True, check=True,
            ).stdout
            path.write_text(''.join(sorted(result.splitlines(keepends=True))))

            rows = [row for row in path.read_text().splitlines() if row and not row.startswith('#')]
            self.assertEqual(rows, sorted(set(rows)))

    def test_boundary_and_support_lists_are_not_append_only(self):
        boundary = (REPO / 'src/test/aiur/events/bus_boundary_test.exs').read_text()
        helper = (REPO / 'src/test/test_helper.exs').read_text()
        self.assertNotIn('@members', boundary)
        self.assertIn('Path.wildcard()', boundary)
        self.assertIn('support/**/*.{ex,exs}', helper)
        self.assertNotIn('Code.require_file("support/build_home/fixture_source.ex"', helper)


if __name__ == '__main__':
    unittest.main(verbosity=2)
