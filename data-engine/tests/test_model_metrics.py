"""Tests for the model metrics computation workflow."""

import pytest

from data_engine.models.messages import HistogramData
from data_engine.workflows.model_metrics import compute_metrics, UnsupportedDistributionError


class TestComputeMetrics:
    """Tests for compute_metrics."""

    def test_normal_distribution_returns_all_metrics(self) -> None:
        params = {"sampleSize": 500, "distribution": "normal", "mean": 0.0, "stdDev": 1.0}
        metrics, summary, histogram = compute_metrics(params)

        metric_names = {m.name for m in metrics}
        assert metric_names == {"mean", "median", "stdDev", "min", "max", "skewness", "kurtosis", "sampleSize"}
        assert summary.distribution == "normal"
        assert "p50" in summary.percentiles
        assert isinstance(histogram, HistogramData)

    def test_uniform_distribution(self) -> None:
        params = {"sampleSize": 1000, "distribution": "uniform", "mean": 5.0, "stdDev": 2.0}
        metrics, summary, histogram = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "uniform"
        sample_size_metric = next(m for m in metrics if m.name == "sampleSize")
        assert sample_size_metric.value == 1000.0
        assert histogram.sampleSize == 1000

    def test_exponential_distribution(self) -> None:
        params = {"sampleSize": 200, "distribution": "exponential", "stdDev": 2.0}
        metrics, summary, histogram = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "exponential"
        assert histogram.sampleSize == 200

    def test_lognormal_distribution(self) -> None:
        params = {"sampleSize": 300, "distribution": "lognormal", "mean": 0.0, "stdDev": 0.5}
        metrics, summary, histogram = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "lognormal"
        assert histogram.sampleSize == 300

    def test_unsupported_distribution_raises(self) -> None:
        params = {"distribution": "unknown"}
        with pytest.raises(UnsupportedDistributionError, match="unknown"):
            compute_metrics(params)

    def test_default_parameters(self) -> None:
        metrics, summary, histogram = compute_metrics({})

        assert len(metrics) == 8
        assert summary.distribution == "normal"
        sample_size_metric = next(m for m in metrics if m.name == "sampleSize")
        assert sample_size_metric.value == 1000.0
        assert histogram.sampleSize == 1000

    def test_percentiles_in_summary(self) -> None:
        _, summary, _ = compute_metrics({"sampleSize": 100})

        for key in ["p5", "p25", "p50", "p75", "p95"]:
            assert key in summary.percentiles

    def test_metric_values_are_rounded(self) -> None:
        metrics, _, _ = compute_metrics({"sampleSize": 100})
        for m in metrics:
            if m.name != "sampleSize":
                str_val = str(m.value)
                if "." in str_val:
                    decimal_places = len(str_val.split(".")[-1])
                    assert decimal_places <= 6


class TestHistogramData:
    """Tests for histogram data computation."""

    def test_histogram_has_50_bins(self) -> None:
        _, _, histogram = compute_metrics({"sampleSize": 1000})

        assert len(histogram.counts) == 50
        assert len(histogram.binEdges) == 51  # n+1 edges for n bins

    def test_histogram_counts_sum_to_sample_size(self) -> None:
        sample_size = 5000
        _, _, histogram = compute_metrics({"sampleSize": sample_size})

        assert sum(histogram.counts) == sample_size
        assert histogram.sampleSize == sample_size

    def test_histogram_bin_edges_are_sorted(self) -> None:
        _, _, histogram = compute_metrics({"sampleSize": 500})

        for i in range(len(histogram.binEdges) - 1):
            assert histogram.binEdges[i] <= histogram.binEdges[i + 1]

    def test_histogram_bin_edges_rounded_to_6_decimals(self) -> None:
        _, _, histogram = compute_metrics({"sampleSize": 1000})

        for edge in histogram.binEdges:
            str_val = str(edge)
            if "." in str_val:
                decimal_places = len(str_val.split(".")[-1])
                assert decimal_places <= 6

    def test_histogram_serializes_to_camel_case(self) -> None:
        _, _, histogram = compute_metrics({"sampleSize": 100})

        data = histogram.model_dump()
        assert "binEdges" in data
        assert "counts" in data
        assert "sampleSize" in data
