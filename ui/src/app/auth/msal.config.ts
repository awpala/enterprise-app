/**
 * MSAL configuration factories for Microsoft Entra External ID (CIAM).
 *
 * Three factory functions are exported — wired into app.config.ts via the
 * MSAL_INSTANCE / MSAL_GUARD_CONFIG / MSAL_INTERCEPTOR_CONFIG injection tokens.
 *
 * Authority format for External ID:
 *   https://<tenant-subdomain>.ciamlogin.com/<tenantId>
 *
 * `knownAuthorities` MUST be populated with the ciamlogin.com host because
 * it is not in MSAL's built-in trusted-authority list (unlike login.microsoftonline.com).
 */
import {
  IPublicClientApplication,
  PublicClientApplication,
  InteractionType,
  BrowserCacheLocation,
  LogLevel,
} from '@azure/msal-browser';
import {
  MsalGuardConfiguration,
  MsalInterceptorConfiguration,
} from '@azure/msal-angular';

import { environment } from '../environments/environment';

/**
 * Extracts the host (e.g. `eadev.ciamlogin.com`) from the full authority URL
 * so MSAL can trust the non-standard External ID authority.
 */
function authorityHost(authority: string): string {
  try {
    return new URL(authority).host;
  } catch {
    return '';
  }
}

/**
 * Runtime-derived redirect URI. Using window.location.origin avoids baking
 * environment-specific FQDNs into the SPA bundle (localhost vs SWA FQDN).
 */
function redirectUri(): string {
  return typeof window !== 'undefined'
    ? window.location.origin + '/auth/redirect'
    : '/auth/redirect';
}

function postLogoutRedirectUri(): string {
  return typeof window !== 'undefined' ? window.location.origin : '/';
}

/**
 * The API scope we request on login. MSAL will cache the access token and
 * the interceptor will attach it to outbound HTTP calls to the API.
 */
const apiScopes: string[] = [environment.aadApiScope];

export function msalInstanceFactory(): IPublicClientApplication {
  const knownHost = authorityHost(environment.aadAuthority);

  return new PublicClientApplication({
    auth: {
      clientId: environment.aadClientId,
      authority: environment.aadAuthority,
      knownAuthorities: knownHost ? [knownHost] : [],
      redirectUri: redirectUri(),
      postLogoutRedirectUri: postLogoutRedirectUri(),
      navigateToLoginRequestUrl: true,
    },
    cache: {
      cacheLocation: BrowserCacheLocation.LocalStorage,
      storeAuthStateInCookie: false,
    },
    system: {
      loggerOptions: {
        loggerCallback: (_level, message, containsPii) => {
          if (containsPii || environment.production) {
            return;
          }
          // eslint-disable-next-line no-console
          console.debug('[MSAL]', message);
        },
        logLevel: environment.production ? LogLevel.Warning : LogLevel.Info,
        piiLoggingEnabled: false,
      },
    },
  });
}

export function msalGuardConfigFactory(): MsalGuardConfiguration {
  return {
    interactionType: InteractionType.Redirect,
    authRequest: {
      scopes: apiScopes,
    },
    loginFailedRoute: '/login-failed',
  };
}

export function msalInterceptorConfigFactory(): MsalInterceptorConfiguration {
  // Guard against a trailing slash on apiUrl so the map key is deterministic.
  const base = (environment.apiUrl ?? '').replace(/\/+$/, '');
  const protectedResourceMap = new Map<string, string[] | null>();

  if (base) {
    protectedResourceMap.set(`${base}/api/`, apiScopes);
  }

  return {
    interactionType: InteractionType.Redirect,
    protectedResourceMap,
  };
}
