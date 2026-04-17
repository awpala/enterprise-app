import { Component, inject, OnInit, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { MatChipsModule } from '@angular/material/chips';
import { MatCardModule } from '@angular/material/card';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDialog } from '@angular/material/dialog';
import { DatePipe } from '@angular/common';
import { ModelService } from '../../../core/services/model.service';
import { StatusBadgeComponent } from '../../../shared/components/status-badge/status-badge.component';
import { ConfirmDialogComponent } from '../../../shared/components/confirm-dialog/confirm-dialog.component';
import { Model, ModelStatus } from '../../../shared/models/model.interface';

@Component({
  selector: 'app-model-list',
  standalone: true,
  imports: [
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatPaginatorModule,
    MatChipsModule,
    MatCardModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    MatTooltipModule,
    DatePipe,
    StatusBadgeComponent,
    RouterLink,
  ],
  templateUrl: './model-list.component.html',
  styleUrl: './model-list.component.scss',
})
export class ModelListComponent implements OnInit {
  private readonly modelService = inject(ModelService);
  private readonly router = inject(Router);
  private readonly snackBar = inject(MatSnackBar);
  private readonly dialog = inject(MatDialog);

  readonly loading = signal(true);
  readonly models = signal<Model[]>([]);
  readonly totalCount = signal(0);
  readonly page = signal(1);
  readonly pageSize = signal(20);
  readonly statusFilter = signal<ModelStatus | undefined>(undefined);
  readonly displayedColumns = ['name', 'status', 'version', 'createdBy', 'updatedAtUtc', 'actions'];
  readonly statusOptions: (ModelStatus | 'All')[] = ['All', 'Draft', 'Active', 'Archived'];

  ngOnInit(): void {
    this.loadModels();
  }

  onStatusFilter(status: ModelStatus | 'All'): void {
    this.statusFilter.set(status === 'All' ? undefined : status);
    this.page.set(1);
    this.loadModels();
  }

  onPageChange(event: PageEvent): void {
    this.page.set(event.pageIndex + 1);
    this.pageSize.set(event.pageSize);
    this.loadModels();
  }

  navigateToModel(model: Model): void {
    this.router.navigate(['/models', model.id]);
  }

  deleteModel(event: Event, model: Model): void {
    event.stopPropagation();
    const ref = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Archive Model',
        message: `Are you sure you want to archive "${model.name}"?`,
        confirmText: 'Archive',
      },
    });

    ref.afterClosed().subscribe(confirmed => {
      if (confirmed) {
        this.modelService.deleteModel(model.id).subscribe({
          next: () => {
            this.snackBar.open('Model archived', 'OK', { duration: 3000 });
            this.loadModels();
          },
          error: (err: unknown) => {
            console.error('[ModelListComponent] Failed to archive model', model.id, err);
            this.snackBar.open('Failed to archive model', 'OK', { duration: 3000 });
          },
        });
      }
    });
  }

  private loadModels(): void {
    this.loading.set(true);
    this.modelService.getModels(this.page(), this.pageSize(), this.statusFilter()).subscribe({
      next: result => {
        this.models.set(result.items);
        this.totalCount.set(result.totalCount);
        this.loading.set(false);
      },
      error: (err: unknown) => {
        console.error('[ModelListComponent] Failed to load models', err);
        this.snackBar.open('Failed to load models', 'OK', { duration: 3000 });
        this.loading.set(false);
      },
    });
  }
}
