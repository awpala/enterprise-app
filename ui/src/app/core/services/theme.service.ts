import { DOCUMENT } from '@angular/common';
import { effect, inject, Injectable } from '@angular/core';

import { UI_STATE_KEYS, UiStateService } from './ui-state.service';

/** Supported color schemes for the application shell. */
export type Theme = 'light' | 'dark';

/** CSS class applied to `document.body` when dark mode is active. */
const DARK_THEME_CLASS = 'dark-theme';

/**
 * Owns the active light/dark theme for the SPA.
 *
 * Seeding priority on first load:
 *   1. Persisted value in `localStorage` (via {@link UiStateService}).
 *   2. OS preference via `matchMedia('(prefers-color-scheme: dark)')`.
 *   3. Fallback to `'light'`.
 *
 * The active class is applied to `document.body` through an {@link effect} so
 * that both signal updates and the initial seed take a single code path.
 */
@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly uiState = inject(UiStateService);
  private readonly document = inject(DOCUMENT);

  /** Reactive current theme. Writes propagate to localStorage automatically. */
  readonly theme = this.uiState.signalFor<Theme>(UI_STATE_KEYS.theme, this.seedInitialTheme());

  constructor() {
    effect(() => {
      const current = this.theme();
      const body = this.document.body;
      if (!body) return;
      body.classList.toggle(DARK_THEME_CLASS, current === 'dark');
      // Keep the UA in sync so form controls, scrollbars, etc. follow the theme.
      this.document.documentElement.style.colorScheme = current;
    });
  }

  /** Flip between light and dark. */
  toggle(): void {
    this.theme.update(current => (current === 'dark' ? 'light' : 'dark'));
  }

  /**
   * Determine the initial theme when no persisted value exists. Safe to call
   * in non-browser contexts (returns `'light'` when `matchMedia` is absent).
   */
  private seedInitialTheme(): Theme {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') {
      return 'light';
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
}
