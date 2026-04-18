import { Component, computed, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
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
import { debounceTime } from 'rxjs/operators';
import { ModelService } from '../../../core/services/model.service';
import { UiStateService, UI_STATE_KEYS } from '../../../core/services/ui-state.service';
import { ModelStatus } from '../../../shared/models/model.interface';

/**
 * Shape of a persisted model-form draft. Mirrors the reactive form's value
 * so `patchValue` can restore it directly.
 */
interface ModelFormDraft {
  name: string;
  description: string;
  status: ModelStatus;
  parameters: {
    distribution: string;
    mean: number;
    stdDev: number;
    sampleSize: number;
  };
}

/** Debounce interval for persisting form edits to localStorage. */
const DRAFT_PERSIST_DEBOUNCE_MS = 300;

/** Defaults used for a brand-new (create-mode) form. */
const EMPTY_FORM_VALUE: ModelFormDraft = {
  name: '',
  description: '',
  status: 'Draft',
  parameters: {
    distribution: 'normal',
    mean: 0,
    stdDev: 1.0,
    sampleSize: 1000,
  },
};

/**
 * Empty baseline used when the form is "cleared" — fully-empty fields. This is
 * the server-snapshot equivalent against which a cleared form shows no net
 * change (so submit would be disabled from an all-empty starting state), but
 * in edit mode it differs from the real server snapshot, so Clear correctly
 * enables submit.
 */
const CLEARED_FORM_VALUE: ModelFormDraft = {
  name: '',
  description: '',
  status: 'Draft',
  parameters: {
    distribution: '',
    mean: null as unknown as number,
    stdDev: null as unknown as number,
    sampleSize: null as unknown as number,
  },
};

/**
 * Structural equality for plain JSON-like values (primitives, arrays, plain
 * objects). Sufficient for comparing form values — which are exactly that.
 * Inlined to avoid adding a dependency such as lodash.
 */
function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') {
    return false;
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  const ao = a as Record<string, unknown>;
  const bo = b as Record<string, unknown>;
  const ak = Object.keys(ao);
  const bk = Object.keys(bo);
  if (ak.length !== bk.length) return false;
  for (const k of ak) {
    if (!Object.prototype.hasOwnProperty.call(bo, k)) return false;
    if (!deepEqual(ao[k], bo[k])) return false;
  }
  return true;
}

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
  private readonly uiState = inject(UiStateService);
  private readonly destroyRef = inject(DestroyRef);

  readonly loading = signal(false);
  readonly saving = signal(false);
  readonly isEdit = signal(false);
  readonly modelId = signal<string | null>(null);
  readonly statusOptions: ModelStatus[] = ['Draft', 'Active', 'Archived'];
  readonly distributionOptions = ['normal', 'uniform', 'exponential', 'lognormal'] as const;

  readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.maxLength(200)]],
    description: ['', [Validators.maxLength(2000)]],
    status: ['Draft' as ModelStatus],
    parameters: this.fb.group({
      distribution: ['normal', [Validators.required]],
      mean: [0, [Validators.required]],
      stdDev: [1.0, [Validators.required, Validators.min(0.0001)]],
      sampleSize: [1000, [Validators.required, Validators.min(1), Validators.max(100000)]],
    }),
  });

  /**
   * Baseline against which "net change" is measured. In edit mode this is the
   * server-loaded snapshot; in create mode it is the all-empty defaults.
   */
  private readonly baseline = signal<ModelFormDraft>(EMPTY_FORM_VALUE);

  /**
   * Live form value as a signal so `hasNetChange` can reactively recompute.
   * Emits synchronously on every form edit.
   */
  private readonly currentValue = toSignal(this.form.valueChanges, {
    initialValue: this.form.getRawValue(),
  });

  /**
   * Live form status as a signal. `AbstractControl.valid` is a plain getter —
   * not a signal — so a `computed` that reads `form.valid` directly will not
   * recompute when validity changes. Deriving from `statusChanges` makes the
   * dependency explicit and reactive.
   */
  private readonly formStatus = toSignal(this.form.statusChanges, {
    initialValue: this.form.status,
  });

  /**
   * True when the current form value differs from the baseline (deep equality).
   * This catches the revert-to-original case so the Update button disables
   * again when the user manually reverts their edits.
   */
  readonly hasNetChange = computed(
    () => !deepEqual(this.currentValue(), this.baseline()),
  );

  /**
   * Whether the submit button is enabled.
   *
   * Gate:
   *  - Form must be VALID (required + range validators pass).
   *  - Not currently saving.
   *  - Either `hasNetChange` (deep-equal check) OR the form has been touched
   *    since baseline was set (Angular's built-in dirty tracking via
   *    `markAsPristine()` calls in `loadModel` / `onClear` / `onCancel`).
   *
   * The dirty-OR-netchange union is deliberate: deep-equal alone is brittle
   * against object-reference subtleties across async HTTP hydration, so we
   * accept Angular's dirty signal as a second, canonical indicator of user
   * intent. The deep-equal branch still lets users revert edits to disable
   * Update, which pure dirty-tracking can't do on its own.
   */
  readonly canSubmit = computed(() => {
    // Read currentValue so this computed recomputes on every valueChanges
    // emission — `form.dirty` is a plain getter, not a signal.
    this.currentValue();
    return this.formStatus() === 'VALID'
      && !this.saving()
      && (this.form.dirty || this.hasNetChange());
  });

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.isEdit.set(true);
      this.modelId.set(id);
      this.loadModel(id);
    } else {
      // Create mode: start with fully-empty fields (no prepopulated parameter
      // defaults). Baseline matches so `hasNetChange` is false on initial load
      // and required-field validators gate submit until the user fills them.
      this.form.reset(CLEARED_FORM_VALUE);
      this.baseline.set(CLEARED_FORM_VALUE);
      this.form.markAsPristine();
      // Restore any in-progress create draft.
      this.restoreDraft();
      if (this.hasNetChange()) {
        this.form.markAsDirty();
      }
    }

    // Persist drafts on value changes (debounced).
    this.form.valueChanges
      .pipe(debounceTime(DRAFT_PERSIST_DEBOUNCE_MS), takeUntilDestroyed(this.destroyRef))
      .subscribe(() => {
        // Skip persistence while initial edit-mode hydration is in flight.
        if (this.loading()) return;
        this.uiState.set<ModelFormDraft>(this.draftKey(), this.form.getRawValue() as ModelFormDraft);
      });
  }

  onSubmit(): void {
    if (this.form.invalid) return;

    this.saving.set(true);
    const { name, description, status, parameters } = this.form.value;

    const parsedParams: Record<string, unknown> | null = parameters ? {
      distribution: parameters.distribution,
      mean: parameters.mean,
      stdDev: parameters.stdDev,
      sampleSize: parameters.sampleSize,
    } : null;

    if (this.isEdit()) {
      this.modelService.updateModel(this.modelId()!, {
        name: name!,
        description: description || null,
        status: status as ModelStatus,
        parameters: parsedParams,
      }).subscribe({
        next: model => {
          this.uiState.remove(this.draftKey());
          this.snackBar.open('Model updated', 'OK', { duration: 3000 });
          this.router.navigate(['/models', model.id]);
        },
        error: (err: unknown) => {
          console.error('[ModelFormComponent] Failed to update model', this.modelId(), err);
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
          this.uiState.remove(this.draftKey());
          this.snackBar.open('Model created', 'OK', { duration: 3000 });
          this.router.navigate(['/models', model.id]);
        },
        error: (err: unknown) => {
          console.error('[ModelFormComponent] Failed to create model', err);
          this.snackBar.open('Failed to create model', 'OK', { duration: 3000 });
          this.saving.set(false);
        },
      });
    }
  }

  /**
   * Cancel discards the in-progress edits (including the persisted draft) and
   * navigates away from the form — back to the model detail in edit mode, or
   * the list in create mode — analogously to a successful submit.
   */
  onCancel(): void {
    this.uiState.remove(this.draftKey());
    this.form.reset(this.baseline());
    this.form.markAsPristine();
    if (this.isEdit()) {
      this.router.navigate(['/models', this.modelId()!]);
    } else {
      this.router.navigate(['/models']);
    }
  }

  /**
   * Empty every field, regardless of mode. Does not persist to the server —
   * the user must explicitly click Update/Create. In edit mode this leaves the
   * form in a state that differs from the server baseline, so the submit
   * button becomes enabled.
   */
  onClear(): void {
    this.uiState.remove(this.draftKey());
    this.form.reset(CLEARED_FORM_VALUE);
    // In edit mode, clearing differs from the server baseline so the form is
    // dirty; in create mode it matches the cleared baseline and stays pristine.
    if (this.isEdit()) {
      this.form.markAsDirty();
    } else {
      this.form.markAsPristine();
    }
    this.snackBar.open('Form cleared', 'OK', { duration: 2000 });
  }

  private draftKey(): string {
    const id = this.modelId();
    return id ? UI_STATE_KEYS.modelFormDraftEdit(id) : UI_STATE_KEYS.modelFormDraft;
  }

  private restoreDraft(): void {
    const draft = this.uiState.get<ModelFormDraft | null>(this.draftKey(), null);
    if (draft) {
      this.form.patchValue(draft);
    }
  }

  private loadModel(id: string): void {
    this.loading.set(true);
    this.modelService.getModel(id).subscribe({
      next: model => {
        const serverSnapshot: ModelFormDraft = {
          name: model.name,
          description: model.description ?? '',
          status: model.status,
          parameters: {
            distribution: (model.parameters?.['distribution'] as string) ?? 'normal',
            mean: (model.parameters?.['mean'] as number) ?? 0,
            stdDev: (model.parameters?.['stdDev'] as number) ?? 1.0,
            sampleSize: (model.parameters?.['sampleSize'] as number) ?? 1000,
          },
        };
        this.form.patchValue(serverSnapshot);
        // Server snapshot becomes the baseline for net-change detection.
        this.baseline.set(serverSnapshot);
        // `form.dirty` is managed manually — clear it now that the form
        // matches the server snapshot. Subsequent user edits will flip it
        // back to dirty, which `canSubmit` reads.
        this.form.markAsPristine();
        this.loading.set(false);
        // Apply any locally persisted edit-mode draft over the server values.
        this.restoreDraft();
        // If a draft was restored, the form differs from baseline → mark dirty
        // so the Update button activates.
        if (this.hasNetChange()) {
          this.form.markAsDirty();
        }
      },
      error: (err: unknown) => {
        console.error('[ModelFormComponent] Failed to load model for editing', id, err);
        this.snackBar.open('Model not found', 'OK', { duration: 3000 });
        this.router.navigate(['/models']);
      },
    });
  }
}
