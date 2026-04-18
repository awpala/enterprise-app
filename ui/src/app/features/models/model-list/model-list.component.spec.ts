import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatDialog } from '@angular/material/dialog';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

import { ModelListComponent } from './model-list.component';
import { ModelService } from '../../../core/services/model.service';
import { UiStateService, UI_STATE_KEYS } from '../../../core/services/ui-state.service';

function createModelServiceSpy() {
  return {
    getModels: vi.fn().mockReturnValue(of({ items: [], totalCount: 0, page: 1, pageSize: 20 })),
    getModel: vi.fn().mockReturnValue(of(null)),
    createModel: vi.fn(),
    updateModel: vi.fn(),
    deleteModel: vi.fn().mockReturnValue(of(void 0)),
  };
}

function configureBed(modelService = createModelServiceSpy()) {
  TestBed.configureTestingModule({
    imports: [ModelListComponent],
    providers: [
      provideNoopAnimations(),
      provideRouter([]),
      { provide: ModelService, useValue: modelService },
      { provide: MatSnackBar, useValue: { open: vi.fn() } },
      { provide: MatDialog, useValue: { open: vi.fn() } },
    ],
  });
  return { modelService };
}

describe('ModelListComponent table-state persistence', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => localStorage.clear());

  it('seeds statusFilter and pageSize from persisted values', () => {
    const ui = new UiStateService();
    ui.set(UI_STATE_KEYS.modelsTableFilter, 'Active');
    ui.set(UI_STATE_KEYS.modelsTablePageSize, 50);

    const { modelService } = configureBed();
    const fixture = TestBed.createComponent(ModelListComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    expect(cmp.statusFilter()).toBe('Active');
    expect(cmp.pageSize()).toBe(50);
    expect(modelService.getModels).toHaveBeenCalledWith(1, 50, 'Active');
  });

  it('defaults to undefined filter and pageSize=20 when nothing persisted', () => {
    configureBed();
    const fixture = TestBed.createComponent(ModelListComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    expect(cmp.statusFilter()).toBeUndefined();
    expect(cmp.pageSize()).toBe(20);
  });

  it('persists statusFilter to storage on filter change', () => {
    configureBed();
    const fixture = TestBed.createComponent(ModelListComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    cmp.onStatusFilter('Draft');

    const ui = TestBed.inject(UiStateService);
    expect(ui.get<string>(UI_STATE_KEYS.modelsTableFilter, '')).toBe('Draft');
  });

  it('persists pageSize to storage on pagination change', () => {
    configureBed();
    const fixture = TestBed.createComponent(ModelListComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    cmp.onPageChange({ pageIndex: 2, pageSize: 100, length: 300 });

    const ui = TestBed.inject(UiStateService);
    expect(ui.get<number>(UI_STATE_KEYS.modelsTablePageSize, 0)).toBe(100);
    expect(cmp.pageSize()).toBe(100);
    expect(cmp.page()).toBe(3);
  });
});
