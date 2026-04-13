import { Component, effect, inject } from '@angular/core';
import { Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from './auth.service';

/**
 * Fallback page shown when MsalGuard redirects because login did not succeed.
 * Gives the user an explicit "try again" affordance rather than an infinite
 * redirect loop.
 *
 * Retry behavior: navigating away to `/dashboard` lets `authGuard` → `MsalGuard`
 * initiate the login with `redirectStartPage=/dashboard`, so a successful retry
 * lands the user on the dashboard rather than back on this failure page.
 * Calling `authService.loginRedirect()` directly here would leave
 * `redirectStartPage` pointing at `/login-failed`, and the post-auth
 * `navigateToLoginRequestUrl` hop would return the (now authenticated) user
 * right back to this error screen — confusing and wrong.
 *
 * If the user actually does have a live session when landing here (e.g. a race
 * where auth succeeded but the guard had already scheduled the failure
 * navigation), the auth-aware effect below auto-navigates to `/dashboard`
 * without requiring a click — mirrors `LandingComponent`'s pattern.
 */
@Component({
  selector: 'app-login-failed',
  standalone: true,
  imports: [MatButtonModule, MatIconModule],
  template: `
    <div class="error-container">
      <mat-icon>error_outline</mat-icon>
      <h2>Sign-in failed</h2>
      <p>We could not complete sign-in. Please try again.</p>
      <button mat-raised-button color="primary" (click)="retry()">
        Try again
      </button>
    </div>
  `,
})
export class LoginFailedComponent {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  constructor() {
    effect(() => {
      if (this.authService.isAuthenticated()) {
        void this.router.navigate(['/dashboard']);
      }
    });
  }

  retry(): void {
    void this.router.navigate(['/dashboard']);
  }
}
