/**
 * AuthService wraps MsalService + MsalBroadcastService and projects MSAL's
 * observable state into Angular signals so components can read auth state
 * reactively without manual subscription plumbing.
 *
 * Three independent affordances:
 *  - `loginRedirect()` — real MSAL / Entra External ID sign-in. Available
 *    when `isMsalConfigured` is true (AAD_* values populated).
 *  - `loginAsDev()` — synthetic session matching the backend's DevAuthHandler
 *    sentinel principal. Available when `isDevModeEnabled` is true (local
 *    dev + deployed dev, OFF in prod — driven by ENABLE_DEV_AUTH).
 *  - `loginAsGuest()` — synthetic demo session matching the backend's guest
 *    sentinel principal. Available when `isGuestModeEnabled` is true (prod
 *    only — driven by ENABLE_GUEST_AUTH). Guest and Dev are INDEPENDENT
 *    flags; do not derive one from the other. Guest and Dev code paths are
 *    deliberately kept parallel rather than collapsed into a single
 *    "synthetic session" abstraction.
 *
 * Claims contract (Entra External ID):
 *  - `name`        — display name (may be absent for email OTP accounts)
 *  - `preferred_username` / `username` — email-ish identifier, always present
 *  - `idp`         — source identity provider (`google.com`, `live.com`, or
 *                    the upstream Entra tenant id). Absent for local email-OTP
 *                    accounts — defaulted to `'email'` here to match the
 *                    backend `ICurrentUser.Idp` fallback.
 */
import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import {
  MsalBroadcastService,
  MsalService,
} from '@azure/msal-angular';
import {
  AccountInfo,
  AuthenticationResult,
  EventMessage,
  EventType,
  InteractionStatus,
} from '@azure/msal-browser';
import { filter } from 'rxjs/operators';

import { environment } from '../environments/environment';

const DEV_SESSION_STORAGE_KEY = 'ea:dev-session';
const GUEST_SESSION_STORAGE_KEY = 'ea:guest-session';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly msalService = inject(MsalService);
  private readonly msalBroadcastService = inject(MsalBroadcastService);
  private readonly router = inject(Router);

  /** True when MSAL has enough configuration to attempt a real sign-in. */
  readonly isMsalConfigured: boolean = Boolean(
    environment.aadAuthority && environment.aadClientId,
  );

  /**
   * True when the synthetic dev session is available. Driven by the build-time
   * `enableDevAuth` flag — true locally and in deployed dev, false in prod.
   */
  readonly isDevModeEnabled: boolean = environment.enableDevAuth === true;

  /**
   * True when the synthetic guest session is available. Driven by the
   * build-time `enableGuestAuth` flag — true in prod (sales/demo affordance),
   * false in local dev and deployed dev. Fully independent of
   * `isDevModeEnabled`.
   */
  readonly isGuestModeEnabled: boolean = environment.enableGuestAuth === true;

  /**
   * Synthetic dev account. Oid / tid / idp / name match DevAuthHandler's
   * sentinel values so the frontend's view of "who am I" lines up with what
   * the backend stamps into audit columns.
   */
  private readonly devAccount: AccountInfo = {
    homeAccountId: 'dev.localhost',
    environment: 'dev',
    tenantId: '00000000-0000-0000-0000-000000000002',
    username: 'dev@localhost',
    localAccountId: '00000000-0000-0000-0000-000000000001',
    name: 'Dev User',
    idTokenClaims: {
      oid: '00000000-0000-0000-0000-000000000001',
      tid: '00000000-0000-0000-0000-000000000002',
      idp: 'dev',
      name: 'Dev User',
      preferred_username: 'dev@localhost',
    },
  };

  /**
   * Synthetic guest account. Oid / tid / idp / name match the backend's guest
   * sentinel values so the frontend's view of "who am I" lines up with what
   * the backend stamps into audit columns when `AzureAd:AllowGuest=true` and
   * a request arrives without an Authorization header.
   */
  private readonly guestAccount: AccountInfo = {
    homeAccountId: 'guest.demo',
    environment: 'guest',
    tenantId: '00000000-0000-0000-0000-000000000004',
    username: 'guest@demo',
    localAccountId: '00000000-0000-0000-0000-000000000003',
    name: 'Guest User',
    idTokenClaims: {
      oid: '00000000-0000-0000-0000-000000000003',
      tid: '00000000-0000-0000-0000-000000000004',
      idp: 'guest',
      name: 'Guest User',
      preferred_username: 'guest@demo',
    },
  };

  /** True when a real or synthetic session is active. */
  readonly isAuthenticated = signal<boolean>(false);

  /** Currently active account (MSAL or synthetic dev/guest), or null. */
  readonly activeAccount = signal<AccountInfo | null>(null);

  /** True when the current session is the synthetic dev session. */
  readonly isDevSession = signal<boolean>(false);

  /** True when the current session is the synthetic guest session. */
  readonly isGuestSession = signal<boolean>(false);

  /** Human-readable display name, prefers `name`, falls back to `username`. */
  readonly displayName = computed<string>(() => {
    const acct = this.activeAccount();
    if (!acct) {
      return '';
    }
    return acct.name && acct.name.trim().length > 0
      ? acct.name
      : acct.username;
  });

  /**
   * Source identity provider. Reads `idTokenClaims.idp`, defaults to `'email'`
   * for local one-time-passcode accounts where the claim is not emitted.
   */
  readonly idp = computed<string>(() => {
    const acct = this.activeAccount();
    const raw = acct?.idTokenClaims?.['idp'];
    return typeof raw === 'string' && raw.length > 0 ? raw : 'email';
  });

  constructor() {
    // Restore a previously-established dev session across reloads. Only honored
    // when the build still advertises dev auth — stale flags can't grant access
    // in prod.
    if (this.isDevModeEnabled && this.readPersistedDevSession()) {
      this.activeAccount.set(this.devAccount);
      this.isAuthenticated.set(true);
      this.isDevSession.set(true);
    }

    // Restore a previously-established guest session across reloads. Only
    // honored when the build still advertises guest auth — stale flags can't
    // grant access in non-guest builds.
    if (this.isGuestModeEnabled && this.readPersistedGuestSession()) {
      this.activeAccount.set(this.guestAccount);
      this.isAuthenticated.set(true);
      this.isGuestSession.set(true);
    }

    if (!this.isMsalConfigured) {
      // No MSAL wiring to subscribe to.
      return;
    }

    // Keep the active account slot up to date on successful login events.
    this.msalBroadcastService.msalSubject$
      .pipe(
        filter(
          (msg: EventMessage) =>
            msg.eventType === EventType.LOGIN_SUCCESS ||
            msg.eventType === EventType.ACQUIRE_TOKEN_SUCCESS,
        ),
      )
      .subscribe((msg: EventMessage) => {
        const payload = msg.payload as AuthenticationResult | null;
        if (payload?.account) {
          this.msalService.instance.setActiveAccount(payload.account);
        }
        this.refreshMsalState();
      });

    // After every interaction settles, re-read MSAL's account list so signals
    // reflect the current auth state (covers login, logout, and silent renew).
    this.msalBroadcastService.inProgress$
      .pipe(filter((status) => status === InteractionStatus.None))
      .subscribe(() => this.refreshMsalState());
  }

  /** Starts the real MSAL / External ID login redirect. */
  loginRedirect(): void {
    if (!this.isMsalConfigured) {
      console.warn(
        '[AuthService] loginRedirect suppressed — AAD_AUTHORITY / AAD_CLIENT_ID are not configured.',
      );
      return;
    }
    this.msalService.loginRedirect();
  }

  /** Establishes the synthetic dev session. No-op when dev mode is disabled. */
  loginAsDev(): void {
    if (!this.isDevModeEnabled) {
      console.warn('[AuthService] loginAsDev suppressed — dev auth is disabled in this build.');
      return;
    }
    this.persistDevSession(true);
    this.activeAccount.set(this.devAccount);
    this.isAuthenticated.set(true);
    this.isDevSession.set(true);
    void this.router.navigate(['/dashboard']);
  }

  /**
   * Establishes the synthetic guest session. No-op when guest mode is
   * disabled. Mirrors `loginAsDev()` but is tied to the independent
   * `isGuestModeEnabled` flag and persists under a distinct storage key.
   */
  loginAsGuest(): void {
    if (!this.isGuestModeEnabled) {
      console.warn('[AuthService] loginAsGuest suppressed — guest auth is disabled in this build.');
      return;
    }
    this.persistGuestSession(true);
    this.activeAccount.set(this.guestAccount);
    this.isAuthenticated.set(true);
    this.isGuestSession.set(true);
    void this.router.navigate(['/dashboard']);
  }

  /**
   * Signs out of whichever session is active.
   *
   * MSAL branch: we eagerly clear `activeAccount` + `isAuthenticated` BEFORE
   * calling `msalService.logoutRedirect()`. The return hop from External ID is
   * a full page reload, so in theory MSAL's cache is gone by the time we
   * re-hydrate. In practice, though, there is a synchronous window between
   * this call and the browser actually starting to navigate, and reactive
   * views (e.g. `LandingComponent`'s auth-aware effect) can re-render during
   * that window. If those views still see `isAuthenticated=true`, they will
   * route the user back into the authenticated area, which re-triggers
   * `MsalGuard`, which — with the cache now mid-clear — can fall through to
   * `loginFailedRoute`. Clearing here prevents that stale-signal render and
   * avoids the sign-out-becomes-sign-in-failure loop.
   *
   * Dev/Guest branches already clear signals synchronously before navigating.
   */
  logoutRedirect(): void {
    if (this.isGuestSession()) {
      this.persistGuestSession(false);
      this.isGuestSession.set(false);
      this.activeAccount.set(null);
      this.isAuthenticated.set(false);
      void this.router.navigate(['/']);
      return;
    }
    if (this.isDevSession()) {
      this.persistDevSession(false);
      this.isDevSession.set(false);
      this.activeAccount.set(null);
      this.isAuthenticated.set(false);
      void this.router.navigate(['/']);
      return;
    }
    if (this.isMsalConfigured) {
      this.activeAccount.set(null);
      this.isAuthenticated.set(false);
      this.msalService.logoutRedirect();
      return;
    }
    // Safety: nothing to log out of; just return to landing.
    void this.router.navigate(['/']);
  }

  private refreshMsalState(): void {
    // Don't clobber an active synthetic (dev or guest) session if MSAL events
    // fire with no account.
    if (this.isDevSession() || this.isGuestSession()) {
      return;
    }

    const instance = this.msalService.instance;
    const accounts = instance.getAllAccounts();

    if (accounts.length === 0) {
      instance.setActiveAccount(null);
      this.activeAccount.set(null);
      this.isAuthenticated.set(false);
      return;
    }

    let active = instance.getActiveAccount();
    if (!active) {
      active = accounts[0];
      instance.setActiveAccount(active);
    }

    this.activeAccount.set(active);
    this.isAuthenticated.set(true);
  }

  private readPersistedDevSession(): boolean {
    try {
      return window.localStorage.getItem(DEV_SESSION_STORAGE_KEY) === '1';
    } catch (e) {
      console.warn('[AuthService] Failed to read dev session from localStorage', e);
      return false;
    }
  }

  private persistDevSession(active: boolean): void {
    try {
      if (active) {
        window.localStorage.setItem(DEV_SESSION_STORAGE_KEY, '1');
      } else {
        window.localStorage.removeItem(DEV_SESSION_STORAGE_KEY);
      }
    } catch (e) {
      // localStorage unavailable (SSR / private mode) — dev session becomes
      // per-tab, which is acceptable.
      console.warn('[AuthService] Failed to persist dev session to localStorage', e);
    }
  }

  private readPersistedGuestSession(): boolean {
    try {
      return window.localStorage.getItem(GUEST_SESSION_STORAGE_KEY) === '1';
    } catch (e) {
      console.warn('[AuthService] Failed to read guest session from localStorage', e);
      return false;
    }
  }

  private persistGuestSession(active: boolean): void {
    try {
      if (active) {
        window.localStorage.setItem(GUEST_SESSION_STORAGE_KEY, '1');
      } else {
        window.localStorage.removeItem(GUEST_SESSION_STORAGE_KEY);
      }
    } catch (e) {
      // localStorage unavailable (SSR / private mode) — guest session becomes
      // per-tab, which is acceptable.
      console.warn('[AuthService] Failed to persist guest session to localStorage', e);
    }
  }
}
