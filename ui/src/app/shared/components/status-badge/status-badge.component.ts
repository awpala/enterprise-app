import { Component, input } from '@angular/core';
import { MatChipsModule } from '@angular/material/chips';

/**
 * Displays a colored chip for entity status values.
 *
 * Usage: `<app-status-badge [status]="model.status" />`
 */
@Component({
  selector: 'app-status-badge',
  standalone: true,
  imports: [MatChipsModule],
  template: `
    <mat-chip [class]="'status-chip status-' + status().toLowerCase()" highlighted>
      {{ status() }}
    </mat-chip>
  `,
  // Token namespace note: Material 20 reads `--mat-chip-*` (NOT `--mdc-chip-*`).
  // A `highlighted` chip reads its background from
  // `--mat-chip-elevated-selected-container-color`, so bind that. The label
  // color defaults to `--mat-chip-selected-label-text-color` (M3 fallback
  // `on-secondary-container`) which would conflict with these pastel fills
  // in dark mode; pin it to a dark neutral so the status text stays legible
  // on the fixed pastel backgrounds in both themes.
  styles: `
    .status-chip {
      font-size: 12px;
      min-height: 24px;
      --mat-chip-selected-label-text-color: rgba(0, 0, 0, 0.87);
    }
    .status-draft { --mat-chip-elevated-selected-container-color: #e0e0e0; }
    .status-active { --mat-chip-elevated-selected-container-color: #c8e6c9; }
    .status-archived { --mat-chip-elevated-selected-container-color: #ffe0b2; }
    .status-pending { --mat-chip-elevated-selected-container-color: #bbdefb; }
    .status-running { --mat-chip-elevated-selected-container-color: #fff9c4; }
    .status-completed { --mat-chip-elevated-selected-container-color: #c8e6c9; }
    .status-failed { --mat-chip-elevated-selected-container-color: #ffcdd2; }
  `,
})
export class StatusBadgeComponent {
  readonly status = input.required<string>();
}
