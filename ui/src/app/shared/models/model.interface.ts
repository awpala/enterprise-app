/** Status of a Model entity. */
export type ModelStatus = 'Draft' | 'Active' | 'Archived';

/** A Model entity representing a configurable enterprise model. */
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

/** Request payload for creating a new Model. */
export interface CreateModelRequest {
  readonly name: string;
  readonly description?: string | null;
  readonly status?: ModelStatus;
  readonly parameters?: Record<string, unknown> | null;
}

/** Request payload for updating an existing Model. */
export interface UpdateModelRequest {
  readonly name: string;
  readonly description?: string | null;
  readonly status?: ModelStatus;
  readonly parameters?: Record<string, unknown> | null;
}

/** Generic paged result wrapper. */
export interface PagedResult<T> {
  readonly items: T[];
  readonly totalCount: number;
  readonly page: number;
  readonly pageSize: number;
}
