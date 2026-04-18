import { Component, inject, signal, ViewChild } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSidenavModule, MatSidenav } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatIconModule, MatIconRegistry } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatTooltipModule } from '@angular/material/tooltip';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { DomSanitizer } from '@angular/platform-browser';

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
    MatTooltipModule,
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
    const matIconRegistry = inject(MatIconRegistry);
    const domSanitizer = inject(DomSanitizer);

    matIconRegistry.addSvgIconLiteral(
      'github',
      domSanitizer.bypassSecurityTrustHtml(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>'
      )
    );

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
