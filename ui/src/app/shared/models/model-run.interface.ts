/** Status of a Model Run. */
export type ModelRunStatus = 'Pending' | 'Running' | 'Completed' | 'Failed';

/** A Model Run representing a single execution of a Model. */
export interface ModelRun {
  readonly id: string;
  readonly modelId: string;
  readonly status: ModelRunStatus;
  readonly requestedAtUtc: string;
  readonly startedAtUtc: string | null;
  readonly completedAtUtc: string | null;
  readonly resultSummary: Record<string, unknown> | null;
  readonly errorMessage: string | null;
}

/** A Model Run summary for cross-model listing, includes model name. */
export interface RunSummary {
  readonly id: string;
  readonly modelId: string;
  readonly modelName: string;
  readonly status: ModelRunStatus;
  readonly requestedAtUtc: string;
  readonly startedAtUtc: string | null;
  readonly completedAtUtc: string | null;
  readonly errorMessage: string | null;
}

/** Pre-computed histogram bins for distribution visualization. */
export interface HistogramData {
  readonly binEdges: number[];
  readonly counts: number[];
  readonly sampleSize: number;
}

/** Extended Model Run with computed metrics. */
export interface ModelRunDetail extends ModelRun {
  readonly metrics: ModelMetric[];
  readonly sampleData: HistogramData | null;
}

/** A single metric produced by a Model Run. */
export interface ModelMetric {
  readonly id: string;
  readonly modelRunId: string;
  readonly metricName: string;
  readonly metricValue: number;
  readonly calculatedAtUtc: string;
}
