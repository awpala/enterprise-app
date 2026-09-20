import { act, cleanup, renderHook, waitFor } from '@testing-library/react';
import { User } from 'oidc-client-ts';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useAuthSession } from './useAuthSession';

const mocks = vi.hoisted(() => ({
  loaded: new Set<(user: User) => void>(),
  unloaded: new Set<() => void>(),
  expired: new Set<() => void>(),
  getUser: vi.fn<() => Promise<User | null>>(),
  stopSilentRenew: vi.fn(),
  replace: vi.fn(),
}));

vi.mock('next/navigation', () => ({ useRouter: () => ({ replace: mocks.replace }) }));
vi.mock('@/utils/oidcManager', () => ({
  createOidcManager: () => ({
    getUser: mocks.getUser,
    stopSilentRenew: mocks.stopSilentRenew,
    events: {
      addUserLoaded: (callback: (user: User) => void) => mocks.loaded.add(callback),
      removeUserLoaded: (callback: (user: User) => void) => mocks.loaded.delete(callback),
      addUserUnloaded: (callback: () => void) => mocks.unloaded.add(callback),
      removeUserUnloaded: (callback: () => void) => mocks.unloaded.delete(callback),
      addAccessTokenExpired: (callback: () => void) => mocks.expired.add(callback),
      removeAccessTokenExpired: (callback: () => void) => mocks.expired.delete(callback),
    },
  }),
}));

function visitor(name: string): User {
  return new User({
    access_token: 'demo-access-token',
    token_type: 'Bearer',
    expires_at: Math.floor(Date.now() / 1000) + 300,
    profile: {
      iss: 'https://auth.example.test/realms/enterprise-app',
      sub: 'visitor',
      aud: 'ea-ui',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 300,
      name,
      email: 'visitor@example.test',
      idp: 'google',
    },
  });
}

beforeEach(() => {
  localStorage.clear();
  mocks.getUser.mockResolvedValue(visitor('Original session'));
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
    ok: true,
    json: async () => ({
      deploymentTarget: 'coolify',
      apiUrl: 'https://app.example.test',
      auth: {
        provider: 'oidc',
        authority: 'https://auth.example.test/realms/enterprise-app',
        clientId: 'ea-ui',
        apiScope: 'access_as_user',
      },
      enableGuestAuth: true,
      enableDevAuth: false,
    }),
  }));
});

afterEach(() => {
  cleanup();
  mocks.loaded.clear();
  mocks.unloaded.clear();
  mocks.expired.clear();
  vi.clearAllMocks();
  vi.unstubAllGlobals();
});

describe('OIDC session lifecycle', () => {
  it('updates the displayed account after token renewal and clears an expired session', async () => {
    const { result } = renderHook(() => useAuthSession());
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.account?.name).toBe('Original session');

    act(() => mocks.loaded.forEach(callback => callback(visitor('Renewed session'))));
    expect(result.current.account?.name).toBe('Renewed session');

    act(() => mocks.expired.forEach(callback => callback()));
    expect(result.current.isAuthenticated).toBe(false);
  });

  it('removes subscriptions and stops renewal when the provider unmounts', async () => {
    const { result, unmount } = renderHook(() => useAuthSession());
    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(mocks.loaded.size).toBe(1);

    unmount();

    expect(mocks.loaded.size).toBe(0);
    expect(mocks.unloaded.size).toBe(0);
    expect(mocks.expired.size).toBe(0);
    expect(mocks.stopSilentRenew).toHaveBeenCalledOnce();
  });

  it('keeps an explicit guest session independent of OIDC expiry', async () => {
    const { result } = renderHook(() => useAuthSession());
    await waitFor(() => expect(result.current.loading).toBe(false));

    act(() => result.current.loginAsGuest());
    act(() => mocks.expired.forEach(callback => callback()));

    expect(result.current.isAuthenticated).toBe(true);
    expect(result.current.account?.synthetic).toBe('guest');
    expect(await result.current.getAccessToken()).toBeNull();
  });
});
