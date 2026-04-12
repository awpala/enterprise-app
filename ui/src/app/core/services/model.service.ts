import { HttpClient, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  CreateModelRequest,
  Model,
  PagedResult,
  UpdateModelRequest,
} from '../../shared/models/model.interface';

/**
 * Service for CRUD operations on Model entities.
 * Communicates with the ASP.NET Core API at /api/v1/models.
 */
@Injectable({ providedIn: 'root' })
export class ModelService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${environment.apiUrl}/api/v1/models`;

  /**
   * Retrieves a paged list of models, optionally filtered by status.
   * @param page Page number (1-based).
   * @param pageSize Number of items per page.
   * @param status Optional status filter.
   */
  getModels(page = 1, pageSize = 20, status?: string): Observable<PagedResult<Model>> {
    let params = new HttpParams()
      .set('page', page.toString())
      .set('pageSize', pageSize.toString());

    if (status) {
      params = params.set('status', status);
    }

    return this.http.get<PagedResult<Model>>(this.baseUrl, { params });
  }

  /**
   * Retrieves a single model by ID.
   * @param id The model identifier.
   */
  getModel(id: string): Observable<Model> {
    return this.http.get<Model>(`${this.baseUrl}/${id}`);
  }

  /**
   * Creates a new model.
   * @param request The creation payload.
   */
  createModel(request: CreateModelRequest): Observable<Model> {
    return this.http.post<Model>(this.baseUrl, request);
  }

  /**
   * Updates an existing model.
   * @param id The model identifier.
   * @param request The update payload.
   */
  updateModel(id: string, request: UpdateModelRequest): Observable<Model> {
    return this.http.put<Model>(`${this.baseUrl}/${id}`, request);
  }

  /**
   * Deletes a model by ID.
   * @param id The model identifier.
   */
  deleteModel(id: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }
}
