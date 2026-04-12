import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { ModelService } from '../../../core/services/model.service';
import { ModelStatus } from '../../../shared/models/model.interface';

@Component({
  selector: 'app-model-form',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
  ],
  templateUrl: './model-form.component.html',
  styleUrl: './model-form.component.scss',
})
export class ModelFormComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly modelService = inject(ModelService);
  private readonly snackBar = inject(MatSnackBar);

  readonly loading = signal(false);
  readonly saving = signal(false);
  readonly isEdit = signal(false);
  readonly modelId = signal<string | null>(null);
  readonly statusOptions: ModelStatus[] = ['Draft', 'Active', 'Archived'];

  readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.maxLength(200)]],
    description: ['', [Validators.maxLength(2000)]],
    status: ['Draft' as ModelStatus],
    parameters: [''],
  });

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.isEdit.set(true);
      this.modelId.set(id);
      this.loadModel(id);
    }
  }

  onSubmit(): void {
    if (this.form.invalid) return;

    this.saving.set(true);
    const { name, description, status, parameters } = this.form.value;

    let parsedParams: Record<string, unknown> | null = null;
    if (parameters?.trim()) {
      try {
        parsedParams = JSON.parse(parameters);
      } catch {
        this.snackBar.open('Invalid JSON in Parameters field', 'OK', { duration: 3000 });
        this.saving.set(false);
        return;
      }
    }

    if (this.isEdit()) {
      this.modelService.updateModel(this.modelId()!, {
        name: name!,
        description: description || null,
        status: status as ModelStatus,
        parameters: parsedParams,
      }).subscribe({
        next: model => {
          this.snackBar.open('Model updated', 'OK', { duration: 3000 });
          this.router.navigate(['/models', model.id]);
        },
        error: () => {
          this.snackBar.open('Failed to update model', 'OK', { duration: 3000 });
          this.saving.set(false);
        },
      });
    } else {
      this.modelService.createModel({
        name: name!,
        description: description || null,
        parameters: parsedParams,
      }).subscribe({
        next: model => {
          this.snackBar.open('Model created', 'OK', { duration: 3000 });
          this.router.navigate(['/models', model.id]);
        },
        error: () => {
          this.snackBar.open('Failed to create model', 'OK', { duration: 3000 });
          this.saving.set(false);
        },
      });
    }
  }

  onCancel(): void {
    if (this.isEdit()) {
      this.router.navigate(['/models', this.modelId()]);
    } else {
      this.router.navigate(['/models']);
    }
  }

  private loadModel(id: string): void {
    this.loading.set(true);
    this.modelService.getModel(id).subscribe({
      next: model => {
        this.form.patchValue({
          name: model.name,
          description: model.description ?? '',
          status: model.status,
          parameters: model.parameters ? JSON.stringify(model.parameters, null, 2) : '',
        });
        this.loading.set(false);
      },
      error: () => {
        this.snackBar.open('Model not found', 'OK', { duration: 3000 });
        this.router.navigate(['/models']);
      },
    });
  }
}
