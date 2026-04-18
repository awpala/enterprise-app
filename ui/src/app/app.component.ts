import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { ThemeService } from './core/services/theme.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet],
  template: `<router-outlet />`,
})
export class AppComponent {
  // Eagerly instantiate so the persisted/OS-preferred theme is applied to
  // `document.body` before any route (including the unauthenticated landing
  // page) paints.
  private readonly themeService = inject(ThemeService);
}
