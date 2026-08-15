import { describe, expect, it } from 'vitest';
import type { RuntimeConfig } from '@/lib/types';
import { createCognitoLogoutUrl } from './oidcManager';

const config: RuntimeConfig = {
  deploymentTarget: 'aws',
  apiUrl: 'https://api.example.test',
  auth: {
    provider: 'cognito',
    authority: 'https://issuer.example.test',
    clientId: 'public-client-id',
    apiScope: 'openid',
    logoutEndpoint: 'https://logout.example.test',
  },
  enableDevAuth: false,
  enableGuestAuth: false,
};

describe('createCognitoLogoutUrl', () => {
  it('derives the callback from the browser origin', () => {
    const url = createCognitoLogoutUrl(config, 'https://application.example.test');

    expect(url.origin).toBe('https://logout.example.test');
    expect(url.pathname).toBe('/logout');
    expect(url.searchParams.get('client_id')).toBe('public-client-id');
    expect(url.searchParams.get('logout_uri')).toBe('https://application.example.test');
  });
});
