import type {
  Model,
  ModelInput,
  ModelRun,
  ModelRunDetail,
  ModelRunStatus,
  PagedResult,
  RunSummary,
} from './types';

export type AccessTokenProvider = () => Promise<string | null>;

export class ApiClient {
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

  public getModels(page = 1, pageSize = 20, status?: string): Promise<PagedResult<Model>> {
    const query = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
    if (status) query.set('status', status);
    return this.request(`/api/v1/models?${query}`);
  }

  public getModel(id: string): Promise<Model> {
    return this.request(`/api/v1/models/${id}`);
  }

  public createModel(input: ModelInput): Promise<Model> {
    return this.request('/api/v1/models', { method: 'POST', body: JSON.stringify(input) });
  }

  public updateModel(id: string, input: ModelInput): Promise<Model> {
    return this.request(`/api/v1/models/${id}`, { method: 'PUT', body: JSON.stringify(input) });
  }

  public archiveModel(id: string): Promise<void> {
    return this.request(`/api/v1/models/${id}`, { method: 'DELETE' });
  }

  public requestRun(modelId: string): Promise<ModelRun> {
    return this.request(`/api/v1/models/${modelId}/runs`, { method: 'POST', body: '{}' });
  }

  public getRuns(modelId: string): Promise<ModelRun[]> {
    return this.request(`/api/v1/models/${modelId}/runs`);
  }

  public getRun(modelId: string, runId: string): Promise<ModelRunDetail> {
    return this.request(`/api/v1/models/${modelId}/runs/${runId}`);
  }

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
