import { Component, inject, OnInit, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatCardModule } from '@angular/material/card';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { DatePipe } from '@angular/common';
import { ModelService } from '../../core/services/model.service';
import { StatusBadgeComponent } from '../../shared/components/status-badge/status-badge.component';
import { Model } from '../../shared/models/model.interface';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    MatCardModule,
    MatTableModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    DatePipe,
    StatusBadgeComponent,
    RouterLink,
  ],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
})
export class DashboardComponent implements OnInit {
  private readonly modelService = inject(ModelService);
  private readonly router = inject(Router);

  readonly loading = signal(true);
  readonly totalModels = signal(0);
  readonly activeModels = signal(0);
  readonly recentModels = signal<Model[]>([]);
  readonly displayedColumns = ['name', 'status', 'version', 'updatedAtUtc'];

  ngOnInit(): void {
    this.loadDashboard();
  }

  private loadDashboard(): void {
    this.loading.set(true);

    this.modelService.getModels(1, 5).subscribe({
      next: result => {
        this.recentModels.set(result.items);
        this.totalModels.set(result.totalCount);
      },
      error: () => this.loading.set(false),
    });

    this.modelService.getModels(1, 1, 'Active').subscribe({
      next: result => {
        this.activeModels.set(result.totalCount);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  navigateToModel(model: Model): void {
    this.router.navigate(['/models', model.id]);
  }

  navigateToModels(): void {
    this.router.navigate(['/models']);
  }
}
