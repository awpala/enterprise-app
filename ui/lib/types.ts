export type DeploymentTarget = 'local' | 'azure' | 'aws';
export type AuthProvider = 'entra' | 'cognito' | 'none';

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

export type ModelStatus = 'Draft' | 'Active' | 'Archived';
export type ModelRunStatus = 'Pending' | 'Running' | 'Completed' | 'Failed';

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

export interface ModelInput {
  readonly name: string;
  readonly description?: string | null;
  readonly status?: ModelStatus;
  readonly parameters?: Record<string, unknown> | null;
}

export interface PagedResult<T> {
  readonly items: T[];
  readonly totalCount: number;
  readonly page: number;
  readonly pageSize: number;
}

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

export interface RunSummary extends ModelRun {
  readonly modelName: string;
}

export interface HistogramData {
  readonly binEdges: number[];
  readonly counts: number[];
  readonly sampleSize: number;
}

export interface ModelMetric {
  readonly id: string;
  readonly modelRunId: string;
  readonly metricName: string;
  readonly metricValue: number;
  readonly calculatedAtUtc: string;
}

export interface ModelRunDetail extends ModelRun {
  readonly metrics: ModelMetric[];
  readonly sampleData: HistogramData | null;
}
