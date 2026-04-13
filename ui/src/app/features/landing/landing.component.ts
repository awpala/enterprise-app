import { Component, effect, inject } from '@angular/core';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

import { AuthService } from '../../auth/auth.service';

/**
 * Public, unauthenticated landing page. Renders outside of the application
 * layout shell (no toolbar, no sidenav) and surfaces the sign-in affordances.
 *
 * When a signed-in session is detected (either from MSAL cache on load, after
 * the redirect return hop, or from a persisted dev session), the component
 * auto-navigates to `/dashboard`.
 */
@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [MatButtonModule, MatIconModule],
  templateUrl: './landing.component.html',
  styleUrl: './landing.component.scss',
})
export class LandingComponent {
  private readonly router = inject(Router);
  readonly authService = inject(AuthService);

  constructor() {
    effect(() => {
      if (this.authService.isAuthenticated()) {
        void this.router.navigate(['/dashboard']);
      }
    });
  }

  signIn(): void {
    this.authService.loginRedirect();
  }

  signInAsDev(): void {
    this.authService.loginAsDev();
  }
}
