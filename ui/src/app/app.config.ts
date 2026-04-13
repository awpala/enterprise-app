import {
  ApplicationConfig,
  APP_INITIALIZER,
  provideZoneChangeDetection,
} from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptorsFromDi, HTTP_INTERCEPTORS } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import {
  MSAL_GUARD_CONFIG,
  MSAL_INSTANCE,
  MSAL_INTERCEPTOR_CONFIG,
  MsalBroadcastService,
  MsalGuard,
  MsalInterceptor,
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

/**
 * When AAD_* values are empty (no real External ID tenant), MSAL cannot
 * acquire tokens and the MsalInterceptor must be skipped — otherwise every
 * HTTP call throws. In the dev-session code path the backend's DevAuthHandler
 * accepts unauthenticated requests, so omitting the Bearer header is fine.
 */
const isMsalConfigured = Boolean(
  environment.aadAuthority && environment.aadClientId,
);

/**
 * Ensures MSAL has completed its async initialization (and processed any
 * pending redirect response) before Angular's router starts evaluating
 * route guards. Without this, MsalGuard can race initialization on first
 * load and throw `BrowserAuthError: uninitialized_public_client_application`.
 */
function msalInitializerFactory(msalInstance: IPublicClientApplication): () => Promise<void> {
  return async () => {
    await msalInstance.initialize();
    await msalInstance.handleRedirectPromise();
  };
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    // `withInterceptorsFromDi` lets us register MsalInterceptor (a class-based
    // HttpInterceptor) through the classic HTTP_INTERCEPTORS multi-provider.
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
    ...(isMsalConfigured
      ? [
          {
            provide: HTTP_INTERCEPTORS,
            useClass: MsalInterceptor,
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
