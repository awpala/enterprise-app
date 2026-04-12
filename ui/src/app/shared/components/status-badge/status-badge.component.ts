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
  styles: `
    .status-chip {
      font-size: 12px;
      min-height: 24px;
    }
    .status-draft { --mdc-chip-elevated-container-color: #e0e0e0; }
    .status-active { --mdc-chip-elevated-container-color: #c8e6c9; }
    .status-archived { --mdc-chip-elevated-container-color: #ffe0b2; }
    .status-pending { --mdc-chip-elevated-container-color: #bbdefb; }
    .status-running { --mdc-chip-elevated-container-color: #fff9c4; }
    .status-completed { --mdc-chip-elevated-container-color: #c8e6c9; }
    .status-failed { --mdc-chip-elevated-container-color: #ffcdd2; }
  `,
})
export class StatusBadgeComponent {
  readonly status = input.required<string>();
}
