"""Prospective power calibration and bounded solver regressions."""

from statistics import NormalDist
from time import monotonic
import unittest

from analytics.stats.power import estimate, noether_n, simulate, _pvalues
from analytics.stats.power_sampling import draws
from analytics.stats.ranks import mann_whitney_u
from analytics.stats.rng import seed_from

SEED = seed_from('power-fixture')
BASELINE = [10 + NormalDist().inv_cdf((i + .5) / 200) for i in range(200)]


class PowerTest(unittest.TestCase):
    def test_normal_baseline_half_sd_and_noether_published_formula(self):
        # Multiplicative 5% at mean 10 is d=.5, with a slightly smaller B variance.
        power, se = simulate(BASELINE, 64, 64, .05, SEED)
        self.assertAlmostEqual(power, .8, delta=.03)
        self.assertAlmostEqual(se, (power * (1-power) / 1000) ** .5)
        # ceil((z_.975 + z_.8)^2 / (6*(.64-.5)^2)) = 67 per arm.
        self.assertEqual(noether_n(.64), 67)

    def test_sample_solver_monotonic_and_zero_variance_not_estimable(self):
        baseline = [i + 1 for i in range(40)]
        small = estimate(baseline, baseline, .2, SEED, simulations=100)
        large = estimate(baseline, baseline, .3, SEED, simulations=100)
        self.assertLessEqual(large['samples_needed_per_group'], small['samples_needed_per_group'])
        self.assertLess(large['mde_at_current_n'], .9)
        undefined = estimate([7]*40, [6]*40, .2, SEED)
        self.assertEqual(undefined['status'], 'not_estimable')
        self.assertIsNone(undefined['samples_needed_per_group'])
        self.assertIsNone(undefined['power_at_current_n'])

    def test_bounded_search_and_noether_only_exploratory(self):
        result = estimate(BASELINE, BASELINE, .00001, SEED, simulations=30)
        self.assertEqual(result['samples_needed_per_group'], '> 5000')
        result = estimate(BASELINE, BASELINE, .2, SEED, primary=False)
        self.assertEqual(result['simulations'], 0)
        self.assertEqual(result['samples_needed_noether'], 7)
        self.assertIsNone(result['power_at_current_n'])

    def test_counted_rank_method_matches_real_mwu_with_ties(self):
        support, simulations = draws([1, 1, 2, 3], 60, 80, SEED, 10)
        actual = _pvalues(support, simulations, .8, 60, 80)
        for p, pair in zip(actual, simulations):
            a = [x for x, n in zip(support, pair[0]) for _ in range(n)]
            b = [x*.8 for x, n in zip(support, pair[1]) for _ in range(n)]
            self.assertEqual(sum(pair[0]), 60)
            self.assertEqual(sum(pair[1]), 80)
            self.assertAlmostEqual(p, mann_whitney_u(a, b)['p_value'])

    def test_three_primaries_at_n200_under_twenty_seconds(self):
        start = monotonic()
        baseline = list(range(1, 201))
        for i in range(3):
            result = estimate(baseline, [x*.98 for x in baseline], .2, seed_from(str(i)))
            self.assertEqual(result['simulations'], 1000)
            self.assertGreater(result['power_at_current_n'], .8)
        self.assertLess(monotonic()-start, 20)
