import { Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from './auth.service';

/**
 * Fallback page shown when MsalGuard redirects because login did not succeed.
 * Gives the user an explicit "try again" affordance rather than an infinite
 * redirect loop.
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

  retry(): void {
    this.authService.loginRedirect();
  }
}
