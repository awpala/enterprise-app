import { Component, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTableModule } from '@angular/material/table';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DatePipe, JsonPipe } from '@angular/common';
import { interval, filter, switchMap, tap } from 'rxjs';
import { ModelService } from '../../../core/services/model.service';
import { ModelRunService } from '../../../core/services/model-run.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge.component';
import { Model } from '../../../shared/models/model.interface';
import { ModelRun } from '../../../shared/models/model-run.interface';

@Component({
  selector: 'app-model-detail',
  standalone: true,
  imports: [
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatTableModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    DatePipe,
    JsonPipe,
    StatusBadgeComponent,
    RouterLink,
  ],
  templateUrl: './model-detail.component.html',
  styleUrl: './model-detail.component.scss',
})
export class ModelDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly modelService = inject(ModelService);
  private readonly modelRunService = inject(ModelRunService);
  private readonly snackBar = inject(MatSnackBar);
  private readonly destroyRef = inject(DestroyRef);

  readonly loading = signal(true);
  readonly model = signal<Model | null>(null);
  readonly recentRuns = signal<ModelRun[]>([]);
  readonly runRequesting = signal(false);
  readonly runColumns = ['status', 'requestedAtUtc', 'completedAtUtc'];

  private pollingActive = false;

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    this.loadModel(id);
    this.loadRuns(id);
  }

  requestRun(): void {
    const m = this.model();
    if (!m) return;

    this.runRequesting.set(true);
    this.modelRunService.requestRun(m.id).subscribe({
      next: () => {
        this.runRequesting.set(false);
        this.snackBar.open('Run requested', 'OK', { duration: 3000 });
        this.loadRuns(m.id);
      },
      error: (err: unknown) => {
        this.runRequesting.set(false);
        console.error('[ModelDetailComponent] Failed to request run for model', m.id, err);
        this.snackBar.open('Failed to request run', 'OK', { duration: 3000 });
      },
    });
  }

  navigateToRun(run: ModelRun): void {
    this.router.navigate(['/models', run.modelId, 'runs', run.id]);
  }

  private loadModel(id: string): void {
    this.modelService.getModel(id).subscribe({
      next: model => {
        this.model.set(model);
        this.loading.set(false);
      },
      error: (err: unknown) => {
        console.error('[ModelDetailComponent] Failed to load model', id, err);
        this.snackBar.open('Model not found', 'OK', { duration: 3000 });
        this.router.navigate(['/models']);
      },
    });
  }

  private loadRuns(modelId: string): void {
    this.modelRunService.getRuns(modelId).subscribe({
      next: runs => {
        this.recentRuns.set(runs.slice(0, 5));
        this.startPollingIfNeeded(modelId);
      },
      error: (err: unknown) => {
        console.error('[ModelDetailComponent] Failed to load runs for model', modelId, err);
      },
    });
  }

  private startPollingIfNeeded(modelId: string): void {
    const hasInProgress = this.recentRuns().some(r => r.status === 'Pending' || r.status === 'Running');
    if (hasInProgress && !this.pollingActive) {
      this.pollingActive = true;
      interval(5000).pipe(
        takeUntilDestroyed(this.destroyRef),
        filter(() => this.pollingActive),
        switchMap(() => this.modelRunService.getRuns(modelId)),
        tap(runs => {
          this.recentRuns.set(runs.slice(0, 5));
          if (!runs.slice(0, 5).some(r => r.status === 'Pending' || r.status === 'Running')) {
            this.pollingActive = false;
          }
        }),
      ).subscribe();
    }
  }
}
