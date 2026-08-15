"""Core numerical computation workflow for model runs.

Generates sample data based on the requested distribution and computes
summary statistics and percentiles using NumPy / SciPy.
"""

import logging
from typing import Any

import numpy as np
from scipy import stats as sp_stats

from data_engine.models.messages import HistogramData, MetricResult, ResultSummary

logger = logging.getLogger(__name__)

# Supported distribution generators keyed by canonical name.
_DISTRIBUTION_GENERATORS: dict[str, Any] = {
    "normal": lambda rng, n, p: rng.normal(loc=p.get("mean", 0.0), scale=p.get("stdDev", 1.0), size=n),
    "uniform": lambda rng, n, p: rng.uniform(
        low=p.get("mean", 0.0) - p.get("stdDev", 1.0),
        high=p.get("mean", 0.0) + p.get("stdDev", 1.0),
        size=n,
    ),
    "exponential": lambda rng, n, p: rng.exponential(scale=max(p.get("stdDev", 1.0), 1e-9), size=n),
    "lognormal": lambda rng, n, p: rng.lognormal(
        mean=p.get("mean", 0.0), sigma=max(p.get("stdDev", 1.0), 1e-9), size=n
    ),
}


class UnsupportedDistributionError(Exception):
    """Raised when the requested distribution is not recognized."""


def compute_metrics(parameters: dict[str, Any]) -> tuple[list[MetricResult], ResultSummary, HistogramData]:
    """Generate sample data and compute summary statistics.

    Args:
        parameters: Dictionary matching ``ModelRunRequestedParameters``.
            Expected keys: ``sampleSize``, ``distribution``, ``mean``, ``stdDev``.

    Returns:
        A tuple of (metrics list, result summary, histogram data) ready for
        inclusion in a ``ModelRunCompleted`` message.

    Raises:
        UnsupportedDistributionError: If the distribution name is not supported.
    """

    sample_size: int = int(parameters.get("sampleSize", 1000))
    distribution: str = str(parameters.get("distribution", "normal")).lower()
    mean_param: float = float(parameters.get("mean", 0.0))
    std_dev_param: float = float(parameters.get("stdDev", 1.0))

    if distribution not in _DISTRIBUTION_GENERATORS:
        supported = ", ".join(sorted(_DISTRIBUTION_GENERATORS))
        raise UnsupportedDistributionError(
            f"Distribution '{distribution}' is not supported. Supported: {supported}"
        )

    logger.info(
        "Generating %d samples from '%s' distribution (mean=%.4f, stdDev=%.4f)",
        sample_size,
        distribution,
        mean_param,
        std_dev_param,
    )

    rng = np.random.default_rng()
    samples: np.ndarray = _DISTRIBUTION_GENERATORS[distribution](rng, sample_size, parameters)

    # Compute core metrics.
    computed_mean = float(np.mean(samples))
    computed_median = float(np.median(samples))
    computed_std = float(np.std(samples, ddof=1)) if sample_size > 1 else 0.0
    computed_min = float(np.min(samples))
    computed_max = float(np.max(samples))
    computed_skewness = float(sp_stats.skew(samples, bias=False)) if sample_size > 2 else 0.0
    computed_kurtosis = float(sp_stats.kurtosis(samples, bias=False, fisher=True)) if sample_size > 3 else 0.0

    metrics = [
        MetricResult(name="mean", value=round(computed_mean, 6)),
        MetricResult(name="median", value=round(computed_median, 6)),
        MetricResult(name="stdDev", value=round(computed_std, 6)),
        MetricResult(name="min", value=round(computed_min, 6)),
        MetricResult(name="max", value=round(computed_max, 6)),
        MetricResult(name="skewness", value=round(computed_skewness, 6)),
        MetricResult(name="kurtosis", value=round(computed_kurtosis, 6)),
        MetricResult(name="sampleSize", value=float(sample_size)),
    ]

    # Compute percentiles.
    p5, p25, p50, p75, p95 = np.percentile(samples, [5, 25, 50, 75, 95]).tolist()
    percentiles = {
        "p5": round(p5, 6),
        "p25": round(p25, 6),
        "p50": round(p50, 6),
        "p75": round(p75, 6),
        "p95": round(p95, 6),
    }

    result_summary = ResultSummary(distribution=distribution, percentiles=percentiles)

    # Compute histogram bins for visualization (50 bins).
    hist_counts, hist_edges = np.histogram(samples, bins=50)
    histogram_data = HistogramData(
        binEdges=[round(float(e), 6) for e in hist_edges],
        counts=[int(c) for c in hist_counts],
        sampleSize=sample_size,
    )

    logger.info(
        "Metrics computation complete for '%s' distribution: sample_size=%d, computed_mean=%.6f",
        distribution,
        sample_size,
        computed_mean,
    )

    return metrics, result_summary, histogram_data
