import type {
  Model,
  ModelInput,
  ModelRun,
  ModelRunDetail,
  ModelRunStatus,
  PagedResult,
  RunSummary,
} from './types';

/** Supplies the current OIDC access token, or null for a synthetic session. */
export type AccessTokenProvider = () => Promise<string | null>;

/** Typed client for the versioned enterprise API. */
export class ApiClient {
  /** Creates a client bound to one API origin and access-token provider. */
  public constructor(
    private readonly baseUrl: string,
    private readonly getAccessToken: AccessTokenProvider,
  ) {}

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const token = await this.getAccessToken();
    const headers = new Headers(init?.headers);
    headers.set('Accept', 'application/json');
    if (init?.body) headers.set('Content-Type', 'application/json');
    if (token) headers.set('Authorization', `Bearer ${token}`);

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers,
      cache: 'no-store',
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(detail || `${response.status} ${response.statusText}`);
    }

    if (response.status === 204) return undefined as T;
    return response.json() as Promise<T>;
  }

  /** Retrieves a page of models with an optional status filter. */
  public getModels(page = 1, pageSize = 20, status?: string): Promise<PagedResult<Model>> {
    const query = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
    if (status) query.set('status', status);
    return this.request(`/api/v1/models?${query}`);
  }

  /** Retrieves one model by identifier. */
  public getModel(id: string): Promise<Model> {
    return this.request(`/api/v1/models/${id}`);
  }

  /** Creates a model. */
  public createModel(input: ModelInput): Promise<Model> {
    return this.request('/api/v1/models', { method: 'POST', body: JSON.stringify(input) });
  }

  /** Updates a model. */
  public updateModel(id: string, input: ModelInput): Promise<Model> {
    return this.request(`/api/v1/models/${id}`, { method: 'PUT', body: JSON.stringify(input) });
  }

  /** Archives a model. */
  public archiveModel(id: string): Promise<void> {
    return this.request(`/api/v1/models/${id}`, { method: 'DELETE' });
  }

  /** Requests an asynchronous run for a model. */
  public requestRun(modelId: string): Promise<ModelRun> {
    return this.request(`/api/v1/models/${modelId}/runs`, { method: 'POST', body: '{}' });
  }

  /** Retrieves all runs belonging to a model. */
  public getRuns(modelId: string): Promise<ModelRun[]> {
    return this.request(`/api/v1/models/${modelId}/runs`);
  }

  /** Retrieves one run, including its metrics and histogram data. */
  public getRun(modelId: string, runId: string): Promise<ModelRunDetail> {
    return this.request(`/api/v1/models/${modelId}/runs/${runId}`);
  }

  /** Retrieves a page of runs across all models. */
  public getAllRuns(
    page = 1,
    pageSize = 20,
    status?: ModelRunStatus,
  ): Promise<PagedResult<RunSummary>> {
    const query = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
    if (status) query.set('status', status);
    return this.request(`/api/v1/runs?${query}`);
  }
}
