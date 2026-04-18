import { Component, inject, signal, ViewChild } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSidenavModule, MatSidenav } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';

import { AuthService } from '../../../auth/auth.service';
import { UiStateService, UI_STATE_KEYS } from '../../../core/services/ui-state.service';
import { ThemeToggleComponent } from '../theme-toggle/theme-toggle.component';

/**
 * Authenticated application shell (toolbar + sidenav + content outlet).
 *
 * This component is only mounted for routes behind `MsalGuard`, so rendering
 * always implies an authenticated user; the account menu is the only auth
 * affordance surfaced here.
 */
@Component({
  selector: 'app-layout',
  standalone: true,
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatToolbarModule,
    MatSidenavModule,
    MatListModule,
    MatIconModule,
    MatButtonModule,
    MatMenuModule,
    ThemeToggleComponent,
  ],
  templateUrl: './layout.component.html',
  styleUrl: './layout.component.scss',
})
export class LayoutComponent {
  private readonly breakpointObserver = inject(BreakpointObserver);
  private readonly uiState = inject(UiStateService);
  readonly authService = inject(AuthService);

  readonly isMobile = signal(false);

  /** Persisted sidenav open/closed state for desktop. Mobile always starts closed. */
  readonly sidenavOpen = this.uiState.signalFor<boolean>(UI_STATE_KEYS.sidenavOpen, true);

  @ViewChild('sidenav') sidenav!: MatSidenav;

  constructor() {
    this.breakpointObserver.observe([Breakpoints.Handset]).subscribe(result => {
      this.isMobile.set(result.matches);
    });
  }

  onSidenavOpenedChange(opened: boolean): void {
    // Only persist desktop state; mobile overlays shouldn't affect the desktop default.
    if (!this.isMobile()) {
      this.sidenavOpen.set(opened);
    }
  }

  closeSidenavIfMobile(): void {
    if (this.isMobile()) {
      this.sidenav.close();
    }
  }

  signOut(): void {
    this.authService.logoutRedirect();
  }
}
