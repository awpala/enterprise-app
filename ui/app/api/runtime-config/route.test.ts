import { afterEach, describe, expect, it } from 'vitest';
import { GET } from './route';

const originalEnvironment = { ...process.env };

afterEach(() => {
  process.env = { ...originalEnvironment };
});

describe('runtime configuration', () => {
  it('returns local defaults without exposing deployment secrets', async () => {
    delete process.env.DEPLOYMENT_TARGET;
    delete process.env.AUTH_PROVIDER;
    process.env.UNRELATED_SECRET = 'must-not-leak';

    const body = await GET().json();

    expect(body).toMatchObject({
      deploymentTarget: 'local',
      apiUrl: 'http://localhost:8000',
      auth: { provider: 'none' },
      enableDevAuth: true,
    });
    expect(JSON.stringify(body)).not.toContain('must-not-leak');
  });

  it('normalizes AWS OIDC settings at request time', async () => {
    process.env.DEPLOYMENT_TARGET = 'aws';
    process.env.API_URL = 'https://app.example.com/';
    process.env.AUTH_PROVIDER = 'cognito';
    process.env.AUTH_AUTHORITY = 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example';
    process.env.AUTH_CLIENT_ID = 'client-id';
    process.env.AUTH_API_SCOPE = 'https://ea.api/access';
    process.env.AUTH_LOGOUT_ENDPOINT = 'https://ea.auth.us-east-1.amazoncognito.com';
    process.env.ENABLE_DEV_AUTH = 'false';

    const body = await GET().json();

    expect(body).toEqual({
      deploymentTarget: 'aws',
      apiUrl: 'https://app.example.com',
      auth: {
        provider: 'cognito',
        authority: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example',
        clientId: 'client-id',
        apiScope: 'https://ea.api/access',
        logoutEndpoint: 'https://ea.auth.us-east-1.amazoncognito.com',
      },
      enableDevAuth: false,
      enableGuestAuth: false,
    });
  });

  it('rejects an unsupported deployment target', () => {
    process.env.DEPLOYMENT_TARGET = 'unknown-cloud';

    expect(() => GET()).toThrow("Unsupported DEPLOYMENT_TARGET 'unknown-cloud'.");
  });
});
