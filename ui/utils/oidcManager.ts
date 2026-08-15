import { UserManager, WebStorageStateStore } from 'oidc-client-ts';
import type { RuntimeConfig } from '@/lib/types';

/** Creates the browser OIDC manager from public runtime configuration. */
export function createOidcManager(config: RuntimeConfig, origin: string, storage: Storage): UserManager {
  return new UserManager({
    authority: config.auth.authority,
    client_id: config.auth.clientId,
    redirect_uri: `${origin}/auth/callback`,
    post_logout_redirect_uri: `${origin}/`,
    response_type: 'code',
    scope: `openid profile email ${config.auth.apiScope}`.trim(),
    automaticSilentRenew: true,
    userStore: new WebStorageStateStore({ store: storage }),
  });
}

/** Builds the Cognito hosted-UI logout URL for the current application origin. */
export function createCognitoLogoutUrl(config: RuntimeConfig, origin: string): URL {
  const endpoint = new URL('/logout', config.auth.logoutEndpoint);
  endpoint.searchParams.set('client_id', config.auth.clientId);
  endpoint.searchParams.set('logout_uri', origin);
  return endpoint;
}
