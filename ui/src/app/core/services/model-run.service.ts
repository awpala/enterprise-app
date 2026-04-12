import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { ModelRun, ModelRunDetail } from '../../shared/models/model-run.interface';

/**
 * Service for Model Run operations.
 * Communicates with the ASP.NET Core API at /api/v1/models/{modelId}/runs.
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
}
