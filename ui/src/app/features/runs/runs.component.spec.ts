import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { MatSnackBar } from '@angular/material/snack-bar';
import { of } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

import { RunsComponent } from './runs.component';
import { ModelRunService } from '../../core/services/model-run.service';
import { UiStateService, UI_STATE_KEYS } from '../../core/services/ui-state.service';

function createModelRunServiceSpy() {
  return {
    getAllRuns: vi.fn().mockReturnValue(of({ items: [], totalCount: 0, page: 1, pageSize: 20 })),
    getRuns: vi.fn().mockReturnValue(of({ items: [], totalCount: 0, page: 1, pageSize: 20 })),
    getRun: vi.fn(),
    requestRun: vi.fn(),
  };
}

function configureBed(modelRunService = createModelRunServiceSpy()) {
  TestBed.configureTestingModule({
    imports: [RunsComponent],
    providers: [
      provideNoopAnimations(),
      provideRouter([]),
      { provide: ModelRunService, useValue: modelRunService },
      { provide: MatSnackBar, useValue: { open: vi.fn() } },
    ],
  });
  return { modelRunService };
}

describe('RunsComponent table-state persistence', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => localStorage.clear());

  it('seeds statusFilter and pageSize from persisted values', () => {
    const ui = new UiStateService();
    ui.set(UI_STATE_KEYS.runsTableFilter, 'Running');
    ui.set(UI_STATE_KEYS.runsTablePageSize, 50);

    const { modelRunService } = configureBed();
    const fixture = TestBed.createComponent(RunsComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    expect(cmp.statusFilter()).toBe('Running');
    expect(cmp.pageSize()).toBe(50);
    expect(modelRunService.getAllRuns).toHaveBeenCalledWith(1, 50, 'Running');
  });

  it('defaults to undefined filter and pageSize=20 when nothing persisted', () => {
    configureBed();
    const fixture = TestBed.createComponent(RunsComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    expect(cmp.statusFilter()).toBeUndefined();
    expect(cmp.pageSize()).toBe(20);
  });

  it('persists statusFilter to storage on filter change', () => {
    configureBed();
    const fixture = TestBed.createComponent(RunsComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    cmp.onStatusFilterChange('Failed');

    const ui = TestBed.inject(UiStateService);
    expect(ui.get<string>(UI_STATE_KEYS.runsTableFilter, '')).toBe('Failed');
  });

  it('persists pageSize to storage on pagination change', () => {
    configureBed();
    const fixture = TestBed.createComponent(RunsComponent);
    const cmp = fixture.componentInstance;
    fixture.detectChanges();

    cmp.onPageChange({ pageIndex: 1, pageSize: 100, length: 300 });

    const ui = TestBed.inject(UiStateService);
    expect(ui.get<number>(UI_STATE_KEYS.runsTablePageSize, 0)).toBe(100);
    expect(cmp.pageSize()).toBe(100);
    expect(cmp.page()).toBe(2);
  });
});
