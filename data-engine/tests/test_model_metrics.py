"""Tests for the model metrics computation workflow."""

import pytest

from data_engine.workflows.model_metrics import compute_metrics, UnsupportedDistributionError


class TestComputeMetrics:
    """Tests for compute_metrics."""

    def test_normal_distribution_returns_all_metrics(self) -> None:
        params = {"sampleSize": 500, "distribution": "normal", "mean": 0.0, "stdDev": 1.0}
        metrics, summary = compute_metrics(params)

        metric_names = {m.name for m in metrics}
        assert metric_names == {"mean", "median", "stdDev", "min", "max", "skewness", "kurtosis", "sampleSize"}
        assert summary.distribution == "normal"
        assert "p50" in summary.percentiles

    def test_uniform_distribution(self) -> None:
        params = {"sampleSize": 1000, "distribution": "uniform", "mean": 5.0, "stdDev": 2.0}
        metrics, summary = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "uniform"
        sample_size_metric = next(m for m in metrics if m.name == "sampleSize")
        assert sample_size_metric.value == 1000.0

    def test_exponential_distribution(self) -> None:
        params = {"sampleSize": 200, "distribution": "exponential", "stdDev": 2.0}
        metrics, summary = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "exponential"

    def test_lognormal_distribution(self) -> None:
        params = {"sampleSize": 300, "distribution": "lognormal", "mean": 0.0, "stdDev": 0.5}
        metrics, summary = compute_metrics(params)

        assert len(metrics) == 8
        assert summary.distribution == "lognormal"

    def test_unsupported_distribution_raises(self) -> None:
        params = {"distribution": "unknown"}
        with pytest.raises(UnsupportedDistributionError, match="unknown"):
            compute_metrics(params)

    def test_default_parameters(self) -> None:
        metrics, summary = compute_metrics({})

        assert len(metrics) == 8
        assert summary.distribution == "normal"
        sample_size_metric = next(m for m in metrics if m.name == "sampleSize")
        assert sample_size_metric.value == 1000.0

    def test_percentiles_in_summary(self) -> None:
        _, summary = compute_metrics({"sampleSize": 100})

        for key in ["p5", "p25", "p50", "p75", "p95"]:
            assert key in summary.percentiles

    def test_metric_values_are_rounded(self) -> None:
        metrics, _ = compute_metrics({"sampleSize": 100})
        for m in metrics:
            if m.name != "sampleSize":
                str_val = str(m.value)
                if "." in str_val:
                    decimal_places = len(str_val.split(".")[-1])
                    assert decimal_places <= 6
