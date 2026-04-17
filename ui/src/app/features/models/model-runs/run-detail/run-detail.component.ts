import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { DatePipe, DecimalPipe, JsonPipe } from '@angular/common';
import { ModelRunService } from '../../../../core/services/model-run.service';
import { StatusBadgeComponent } from '../../../../shared/components/status-badge/status-badge.component';
import { ModelRunDetail } from '../../../../shared/models/model-run.interface';

@Component({
  selector: 'app-run-detail',
  standalone: true,
  imports: [
    MatCardModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    DatePipe,
    DecimalPipe,
    JsonPipe,
    StatusBadgeComponent,
  ],
  templateUrl: './run-detail.component.html',
  styleUrl: './run-detail.component.scss',
})
export class RunDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly modelRunService = inject(ModelRunService);
  private readonly snackBar = inject(MatSnackBar);

  readonly loading = signal(true);
  readonly modelId = signal('');
  readonly run = signal<ModelRunDetail | null>(null);
  readonly metricColumns = ['metricName', 'metricValue', 'calculatedAtUtc'];

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id')!;
    const runId = this.route.snapshot.paramMap.get('runId')!;
    this.modelId.set(id);

    this.modelRunService.getRun(id, runId).subscribe({
      next: run => {
        this.run.set(run);
        this.loading.set(false);
      },
      error: (err: unknown) => {
        console.error('[RunDetailComponent] Failed to load run', runId, 'for model', id, err);
        this.snackBar.open('Run not found', 'OK', { duration: 3000 });
        this.router.navigate(['/models', id, 'runs']);
      },
    });
  }

  goBack(): void {
    this.router.navigate(['/models', this.modelId(), 'runs']);
  }
}
