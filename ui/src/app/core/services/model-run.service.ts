import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { ModelRun, ModelRunDetail, ModelRunStatus, RunSummary } from '../../shared/models/model-run.interface';
import { PagedResult } from '../../shared/models/model.interface';

/**
 * Service for Model Run operations.
 * Communicates with the ASP.NET Core API at /api/v1/models/{modelId}/runs
 * and /api/v1/runs for cross-model queries.
 */
@Injectable({ providedIn: 'root' })
export class ModelRunService {
  private readonly http = inject(HttpClient);

  private baseUrl(modelId: string): string {
    return `${environment.apiUrl}/api/v1/models/${modelId}/runs`;
  }

  /** Requests a new run for the given model. */
  requestRun(modelId: string): Observable<ModelRun> {
    return this.http.post<ModelRun>(this.baseUrl(modelId), {});
  }

  /** Retrieves all runs for a model. */
  getRuns(modelId: string): Observable<ModelRun[]> {
    return this.http.get<ModelRun[]>(this.baseUrl(modelId));
  }

  /** Retrieves a specific run with metrics. */
  getRun(modelId: string, runId: string): Observable<ModelRunDetail> {
    return this.http.get<ModelRunDetail>(`${this.baseUrl(modelId)}/${runId}`);
  }

  /** Retrieves all runs across all models, paged. */
  getAllRuns(page = 1, pageSize = 20, status?: ModelRunStatus): Observable<PagedResult<RunSummary>> {
    let params = new HttpParams().set('page', page).set('pageSize', pageSize);
    if (status) {
      params = params.set('status', status);
    }
    return this.http.get<PagedResult<RunSummary>>(`${environment.apiUrl}/api/v1/runs`, { params });
  }

  /** Requests runs for multiple models in a batch. */
  requestBatchRun(modelIds: string[]): Observable<RunSummary[]> {
    return this.http.post<RunSummary[]>(`${environment.apiUrl}/api/v1/runs/batch`, { modelIds });
  }
}
