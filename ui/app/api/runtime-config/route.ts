import { NextResponse } from 'next/server';
import type { AuthProvider, DeploymentTarget, RuntimeConfig } from '@/lib/types';

export const dynamic = 'force-dynamic';

function asBoolean(value: string | undefined): boolean {
  return value?.trim().toLowerCase() === 'true';
}

function deploymentTarget(value: string | undefined): DeploymentTarget {
  const target = value?.trim().toLowerCase() ?? 'local';
  if (target === 'local' || target === 'azure' || target === 'aws') return target;
  throw new Error(`Unsupported DEPLOYMENT_TARGET '${value}'.`);
}

function authProvider(value: string | undefined): AuthProvider {
  const provider = value?.trim().toLowerCase() ?? 'none';
  if (provider === 'none' || provider === 'entra' || provider === 'cognito') return provider;
  throw new Error(`Unsupported AUTH_PROVIDER '${value}'.`);
}

export function GET(): NextResponse<RuntimeConfig> {
  const target = deploymentTarget(process.env.DEPLOYMENT_TARGET);
  const provider = authProvider(process.env.AUTH_PROVIDER);
  const authority = process.env.AUTH_AUTHORITY ?? '';
  const clientId = process.env.AUTH_CLIENT_ID ?? '';
  const apiScope = process.env.AUTH_API_SCOPE ?? '';
  const enableDevAuth = asBoolean(process.env.ENABLE_DEV_AUTH ?? (target === 'local' ? 'true' : 'false'));
  const enableGuestAuth = asBoolean(process.env.ENABLE_GUEST_AUTH);

  if (provider !== 'none' && (!authority || !clientId || !apiScope)) {
    throw new Error('AUTH_AUTHORITY, AUTH_CLIENT_ID, and AUTH_API_SCOPE are required when OIDC is enabled.');
  }
  if (target !== 'local' && provider === 'none') {
    throw new Error('AUTH_PROVIDER cannot be none for a cloud deployment.');
  }
  if (enableDevAuth && enableGuestAuth) {
    throw new Error('ENABLE_DEV_AUTH and ENABLE_GUEST_AUTH cannot both be enabled.');
  }

  return NextResponse.json(
    {
      deploymentTarget: target,
      apiUrl: (process.env.API_URL ?? 'http://localhost:8000').replace(/\/$/, ''),
      auth: {
        provider,
        authority,
        clientId,
        apiScope,
        logoutEndpoint: process.env.AUTH_LOGOUT_ENDPOINT ?? '',
      },
      enableDevAuth,
      enableGuestAuth,
    },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
