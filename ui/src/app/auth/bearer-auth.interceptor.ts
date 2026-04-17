/**
 * BearerAuthInterceptor — session-aware replacement for MSAL's stock
 * `MsalInterceptor`.
 *
 * Branching rules:
 *  - Guest session: pass the request through UNCHANGED (no Authorization
 *    header). This is load-bearing: the backend's policy-scheme selector
 *    treats a missing `Authorization: Bearer …` header as the synthetic
 *    guest principal when `AzureAd:AllowGuest=true`. Attaching any Bearer
 *    here would flip the request onto the JwtBearer path and fail.
 *  - Dev session: pass through unchanged. The dev API path accepts
 *    unauthenticated requests (DevAuthHandler).
 *  - Otherwise (real MSAL session): attach an access token via
 *    `acquireTokenSilent` scoped to `environment.aadApiScope`, falling back
 *    to `acquireTokenRedirect` on `InteractionRequiredAuthError`. Only
 *    requests to the configured API base (`environment.apiUrl`) get a token;
 *    unrelated URLs pass through unchanged, matching the
 *    `protectedResourceMap` behavior of MsalInterceptor.
 */
import { HttpHandler, HttpInterceptor, HttpRequest, HttpEvent } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { MsalService } from '@azure/msal-angular';
import {
  AuthenticationResult,
  InteractionRequiredAuthError,
  SilentRequest,
} from '@azure/msal-browser';
import { Observable, from, of, switchMap, catchError, throwError } from 'rxjs';

import { AuthService } from './auth.service';
import { environment } from '../environments/environment';

@Injectable()
export class BearerAuthInterceptor implements HttpInterceptor {
  private readonly authService = inject(AuthService);
  private readonly msalService = inject(MsalService);

  private readonly apiBase: string = (environment.apiUrl ?? '').replace(/\/+$/, '');
  private readonly apiScopes: string[] = environment.aadApiScope
    ? [environment.aadApiScope]
    : [];

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    // Guest sessions MUST NOT send a Bearer — the API selects the guest
    // principal only when Authorization is absent.
    if (this.authService.isGuestSession()) {
      return next.handle(req);
    }

    // Dev sessions are unauthenticated end-to-end; the dev API accepts them
    // without a token.
    if (this.authService.isDevSession()) {
      return next.handle(req);
    }

    // Only attach tokens to calls against the configured API base. Anything
    // else (static assets, App Insights, third-party) passes through.
    if (!this.apiBase || !this.isApiRequest(req.url)) {
      return next.handle(req);
    }

    // No MSAL scope configured — nothing to attach. Let the request through;
    // the API will reject it if auth is required.
    if (this.apiScopes.length === 0) {
      return next.handle(req);
    }

    const instance = this.msalService.instance;
    const account = instance.getActiveAccount() ?? instance.getAllAccounts()[0] ?? null;

    if (!account) {
      // No cached account — nothing to acquire silently against. Pass through
      // and let MsalGuard handle the redirect on the next navigation.
      console.warn('[BearerAuthInterceptor] No cached MSAL account — API request to', req.url, 'will proceed without a Bearer token.');
      return next.handle(req);
    }

    const silentRequest: SilentRequest = {
      scopes: this.apiScopes,
      account,
    };

    return from(this.msalService.instance.acquireTokenSilent(silentRequest)).pipe(
      switchMap((result: AuthenticationResult) => {
        const authed = req.clone({
          setHeaders: {
            Authorization: `Bearer ${result.accessToken}`,
          },
        });
        return next.handle(authed);
      }),
      catchError((err: unknown) => {
        if (err instanceof InteractionRequiredAuthError) {
          console.warn('[BearerAuthInterceptor] Silent token acquisition requires interaction — redirecting to login for', req.url);
          this.msalService.instance.acquireTokenRedirect({
            scopes: this.apiScopes,
            account,
          });
          // The redirect is about to unload the page; emit no events.
          return of();
        }
        console.error('[BearerAuthInterceptor] Token acquisition failed for', req.url, err);
        return throwError(() => err);
      }),
    );
  }

  private isApiRequest(url: string): boolean {
    // Mirror MsalInterceptor's `protectedResourceMap` semantics: only match
    // the `/api/` sub-path under the configured base, keeping health /
    // telemetry endpoints token-free.
    return url.startsWith(`${this.apiBase}/api/`);
  }
}
