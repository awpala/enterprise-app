import {
  ApplicationConfig,
  APP_INITIALIZER,
  ErrorHandler,
  provideZoneChangeDetection,
} from '@angular/core';
import { provideRouter, Router } from '@angular/router';
import { provideHttpClient, withInterceptorsFromDi, HTTP_INTERCEPTORS } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import {
  MSAL_GUARD_CONFIG,
  MSAL_INSTANCE,
  MSAL_INTERCEPTOR_CONFIG,
  MsalBroadcastService,
  MsalGuard,
  MsalService,
} from '@azure/msal-angular';
import { IPublicClientApplication } from '@azure/msal-browser';

import { routes } from './app.routes';
import { environment } from './environments/environment';
import {
  msalGuardConfigFactory,
  msalInstanceFactory,
  msalInterceptorConfigFactory,
} from './auth/msal.config';
import { BearerAuthInterceptor } from './auth/bearer-auth.interceptor';
import { AppInsightsService } from './core/app-insights.service';
import { AppInsightsErrorHandler } from './core/app-insights-error-handler';

/**
 * When AAD_* values are empty (no real External ID tenant), MSAL cannot
 * acquire tokens and the Bearer interceptor must be skipped — otherwise every
 * HTTP call throws. In the dev-session code path the backend's DevAuthHandler
 * accepts unauthenticated requests, and in the guest-session path the API's
 * policy-scheme selector routes header-less requests to the guest principal,
 * so omitting the Bearer header is fine.
 */
const isMsalConfigured = Boolean(
  environment.aadAuthority && environment.aadClientId,
);

/**
 * Pre-initializes MSAL before Angular's router starts evaluating route guards.
 *
 * Single responsibility: await `msalInstance.initialize()` so that MsalGuard
 * does not throw `BrowserAuthError: uninitialized_public_client_application`
 * on first load (the v3 PublicClientApplication requires explicit async init
 * before any other API call).
 *
 * IMPORTANT: this factory intentionally does NOT call `handleRedirectPromise()`.
 * Redirect-response processing is owned by `MsalRedirectComponent`, which the
 * router mounts at the `/auth/redirect` route (see app.routes.ts). There is a
 * single MSAL instance and a single bootstrap — we no longer separately
 * bootstrap `MsalRedirectComponent` into an `<app-redirect>` host element
 * (that dual-bootstrap model caused a double-consumption race and was removed).
 * Calling `handleRedirectPromise()` here would race the routed
 * `MsalRedirectComponent`, silently consume the URL fragment first, and leave
 * the component with `null` — manifesting as a stuck `/auth/redirect` page or
 * a perpetual sign-in loop on the return hop from External ID.
 */
function msalInitializerFactory(msalInstance: IPublicClientApplication): () => Promise<void> {
  return async () => {
    await msalInstance.initialize();
  };
}

function appInsightsInitializerFactory(
  appInsights: AppInsightsService,
  router: Router,
): () => void {
  return () => {
    appInsights.initialize(router);
  };
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    // `withInterceptorsFromDi` lets us register class-based HttpInterceptors
    // through the classic HTTP_INTERCEPTORS multi-provider.
    provideHttpClient(withInterceptorsFromDi()),
    provideAnimationsAsync(),

    {
      provide: MSAL_INSTANCE,
      useFactory: msalInstanceFactory,
    },
    {
      provide: MSAL_GUARD_CONFIG,
      useFactory: msalGuardConfigFactory,
    },
    {
      provide: MSAL_INTERCEPTOR_CONFIG,
      useFactory: msalInterceptorConfigFactory,
    },
    MsalService,
    MsalBroadcastService,
    MsalGuard,
    {
      provide: ErrorHandler,
      useExisting: AppInsightsErrorHandler,
    },
    {
      provide: APP_INITIALIZER,
      useFactory: appInsightsInitializerFactory,
      deps: [AppInsightsService, Router],
      multi: true,
    },
    ...(isMsalConfigured
      ? [
          // Custom session-aware Bearer interceptor replaces MsalInterceptor.
          // It forwards dev/guest sessions unchanged (no Authorization header)
          // and attaches a Bearer via acquireTokenSilent for real MSAL sessions.
          // See auth/bearer-auth.interceptor.ts.
          {
            provide: HTTP_INTERCEPTORS,
            useClass: BearerAuthInterceptor,
            multi: true,
          },
          {
            provide: APP_INITIALIZER,
            useFactory: msalInitializerFactory,
            deps: [MSAL_INSTANCE],
            multi: true,
          },
        ]
      : []),
  ],
};
