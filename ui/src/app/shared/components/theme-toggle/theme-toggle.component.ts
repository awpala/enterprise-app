import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';

import { ThemeService } from '../../../core/services/theme.service';

/**
 * Slider-style light/dark theme toggle with sun/moon icons.
 *
 * Renders a button that behaves as an ARIA switch so screen readers announce
 * the current state and the control is reachable by keyboard.
 */
@Component({
  selector: 'app-theme-toggle',
  standalone: true,
  imports: [MatIconModule, MatTooltipModule],
  templateUrl: './theme-toggle.component.html',
  styleUrl: './theme-toggle.component.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ThemeToggleComponent {
  private readonly themeService = inject(ThemeService);

  readonly isDark = computed(() => this.themeService.theme() === 'dark');
  readonly tooltip = computed(() =>
    this.isDark() ? 'Switch to light mode' : 'Switch to dark mode',
  );

  toggle(): void {
    this.themeService.toggle();
  }
}
