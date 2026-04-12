import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DatePipe } from '@angular/common';
import { ModelRunService } from '../../../core/services/model-run.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge.component';
import { ModelRun } from '../../../shared/models/model-run.interface';

@Component({
  selector: 'app-model-runs',
  standalone: true,
  imports: [
    MatCardModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    DatePipe,
    StatusBadgeComponent,
    RouterLink,
  ],
  templateUrl: './model-runs.component.html',
  styleUrl: './model-runs.component.scss',
})
export class ModelRunsComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly modelRunService = inject(ModelRunService);
  private readonly snackBar = inject(MatSnackBar);

  readonly loading = signal(true);
  readonly modelId = signal('');
  readonly runs = signal<ModelRun[]>([]);
  readonly displayedColumns = ['status', 'requestedAtUtc', 'startedAtUtc', 'completedAtUtc', 'errorMessage'];

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    this.modelId.set(id);
    this.loadRuns();
  }

  navigateToRun(run: ModelRun): void {
    this.router.navigate(['/models', this.modelId(), 'runs', run.id]);
  }

  requestRun(): void {
    this.modelRunService.requestRun(this.modelId()).subscribe({
      next: () => {
        this.snackBar.open('Run requested', 'OK', { duration: 3000 });
        this.loadRuns();
      },
      error: () => this.snackBar.open('Failed to request run', 'OK', { duration: 3000 }),
    });
  }

  private loadRuns(): void {
    this.loading.set(true);
    this.modelRunService.getRuns(this.modelId()).subscribe({
      next: runs => {
        this.runs.set(runs);
        this.loading.set(false);
      },
      error: () => {
        this.snackBar.open('Failed to load runs', 'OK', { duration: 3000 });
        this.loading.set(false);
      },
    });
  }
}
