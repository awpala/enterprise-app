/** Runtime hosting target selected by deployment configuration. */
export type DeploymentTarget = 'local' | 'azure' | 'aws';
/** Browser authentication adapter selected by deployment configuration. */
export type AuthProvider = 'entra' | 'cognito' | 'none';

/** Public, non-secret configuration returned by `/api/runtime-config`. */
export interface RuntimeConfig {
  readonly deploymentTarget: DeploymentTarget;
  readonly apiUrl: string;
  readonly auth: {
    readonly provider: AuthProvider;
    readonly authority: string;
    readonly clientId: string;
    readonly apiScope: string;
    readonly logoutEndpoint: string;
  };
  readonly enableDevAuth: boolean;
  readonly enableGuestAuth: boolean;
}

/** Lifecycle states exposed by the model API. */
export type ModelStatus = 'Draft' | 'Active' | 'Archived';
/** Lifecycle states exposed by the model-run API. */
export type ModelRunStatus = 'Pending' | 'Running' | 'Completed' | 'Failed';

/** Model representation returned by the API. */
export interface Model {
  readonly id: string;
  readonly name: string;
  readonly description: string | null;
  readonly status: ModelStatus;
  readonly version: number;
  readonly parameters: Record<string, unknown> | null;
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly createdBy: string;
}

/** Mutable model fields accepted by create and update operations. */
export interface ModelInput {
  readonly name: string;
  readonly description?: string | null;
  readonly status?: ModelStatus;
  readonly parameters?: Record<string, unknown> | null;
}

/** Generic API page with its total item count. */
export interface PagedResult<T> {
  readonly items: T[];
  readonly totalCount: number;
  readonly page: number;
  readonly pageSize: number;
}

/** Model-run representation shared by list and detail views. */
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

/** Cross-model run summary with its parent model name. */
export interface RunSummary extends ModelRun {
  readonly modelName: string;
}

/** Precomputed histogram bins returned for a completed run. */
export interface HistogramData {
  readonly binEdges: number[];
  readonly counts: number[];
  readonly sampleSize: number;
}

/** Computed numeric metric returned for a completed run. */
export interface ModelMetric {
  readonly id: string;
  readonly modelRunId: string;
  readonly metricName: string;
  readonly metricValue: number;
  readonly calculatedAtUtc: string;
}

/** Detailed model run with computed metrics and histogram data. */
export interface ModelRunDetail extends ModelRun {
  readonly metrics: ModelMetric[];
  readonly sampleData: HistogramData | null;
}
