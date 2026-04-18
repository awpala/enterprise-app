import { Component, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatChipsModule } from '@angular/material/chips';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { DatePipe } from '@angular/common';
import { interval, filter, switchMap, tap } from 'rxjs';
import { ModelRunService } from '../../core/services/model-run.service';
import { StatusBadgeComponent } from '../../shared/components/status-badge/status-badge.component';
import { ModelRunStatus, RunSummary } from '../../shared/models/model-run.interface';

/**
 * Top-level runs view showing runs across all models.
 * Supports status filtering, pagination, and auto-polling for in-progress runs.
 */
@Component({
  selector: 'app-runs',
  standalone: true,
  imports: [
    MatCardModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    MatChipsModule,
    MatPaginatorModule,
    DatePipe,
    StatusBadgeComponent,
  ],
  templateUrl: './runs.component.html',
  styleUrl: './runs.component.scss',
})
export class RunsComponent implements OnInit {
  private readonly router = inject(Router);
  private readonly modelRunService = inject(ModelRunService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly destroyRef = inject(DestroyRef);

  readonly loading = signal(true);
  readonly runs = signal<RunSummary[]>([]);
  readonly totalCount = signal(0);
  readonly page = signal(1);
  readonly pageSize = signal(20);
  readonly statusFilter = signal<ModelRunStatus | undefined>(undefined);
  readonly batchRequesting = signal(false);

  readonly displayedColumns = ['status', 'modelName', 'requestedAtUtc', 'startedAtUtc', 'completedAtUtc', 'errorMessage'];
  readonly statusOptions: Array<{ label: string; value: ModelRunStatus | undefined }> = [
    { label: 'All', value: undefined },
    { label: 'Pending', value: 'Pending' },
    { label: 'Running', value: 'Running' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Failed', value: 'Failed' },
  ];

  private pollingActive = false;

  ngOnInit(): void {
    this.loadRuns();
  }

  /**
   * Filter-chip click handler. Always exactly one chip is "on":
   *  - Click All when All is already selected → no-op.
   *  - Click a non-All chip that is already selected → fall back to All.
   *  - Click any other chip → select it.
   */
  onStatusFilterChange(value: ModelRunStatus | undefined): void {
    const current = this.statusFilter();
    let next: ModelRunStatus | undefined;
    if (value === undefined) {
      if (current === undefined) return;
      next = undefined;
    } else if (current === value) {
      next = undefined;
    } else {
      next = value;
    }
    this.statusFilter.set(next);
    this.page.set(1);
    this.loadRuns();
  }

  onPageChange(event: PageEvent): void {
    this.page.set(event.pageIndex + 1);
    this.pageSize.set(event.pageSize);
    this.loadRuns();
  }

  navigateToRun(run: RunSummary): void {
    this.router.navigate(['/models', run.modelId, 'runs', run.id]);
  }

  refresh(): void {
    this.loadRuns();
  }

  private loadRuns(): void {
    this.loading.set(true);
    this.modelRunService.getAllRuns(this.page(), this.pageSize(), this.statusFilter()).subscribe({
      next: result => {
        this.runs.set(result.items);
        this.totalCount.set(result.totalCount);
        this.loading.set(false);
        this.startPollingIfNeeded();
      },
      error: (err: unknown) => {
        console.error('[RunsComponent] Failed to load runs', err);
        this.snackBar.open('Failed to load runs', 'OK', { duration: 3000 });
        this.loading.set(false);
      },
    });
  }

  private startPollingIfNeeded(): void {
    const hasInProgress = this.runs().some(r => r.status === 'Pending' || r.status === 'Running');
    if (hasInProgress && !this.pollingActive) {
      this.pollingActive = true;
      interval(5000).pipe(
        takeUntilDestroyed(this.destroyRef),
        filter(() => this.pollingActive),
        switchMap(() => this.modelRunService.getAllRuns(this.page(), this.pageSize(), this.statusFilter())),
        tap(result => {
          this.runs.set(result.items);
          this.totalCount.set(result.totalCount);
          if (!result.items.some(r => r.status === 'Pending' || r.status === 'Running')) {
            this.pollingActive = false;
          }
        }),
      ).subscribe();
    }
  }
}
