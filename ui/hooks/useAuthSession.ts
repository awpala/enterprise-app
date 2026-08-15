'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { User, UserManager } from 'oidc-client-ts';
import { useRouter } from 'next/navigation';
import type { RuntimeConfig } from '@/lib/types';
import { accountFromUser, type AuthAccount } from '@/utils/authAccount';
import { createCognitoLogoutUrl, createOidcManager } from '@/utils/oidcManager';

const DEV_SESSION_KEY = 'ea:dev-session';
const GUEST_SESSION_KEY = 'ea:guest-session';

/** Authentication state and actions exposed to application components. */
export interface AuthSession {
  readonly loading: boolean;
  readonly config: RuntimeConfig | null;
  readonly account: AuthAccount | null;
  readonly isAuthenticated: boolean;
  readonly login: () => Promise<void>;
  readonly loginAsDev: () => void;
  readonly loginAsGuest: () => void;
  readonly logout: () => Promise<void>;
  readonly completeLogin: () => Promise<void>;
  readonly getAccessToken: () => Promise<string | null>;
}

/** Owns OIDC and synthetic-session state independently of the context component. */
export function useAuthSession(): AuthSession {
  const router = useRouter();
  const [config, setConfig] = useState<RuntimeConfig | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [synthetic, setSynthetic] = useState<'dev' | 'guest' | null>(null);
  const [loading, setLoading] = useState(true);
  const managerRef = useRef<UserManager | null>(null);

  useEffect(() => {
    let active = true;
    void fetch('/api/runtime-config', { cache: 'no-store' })
      .then(async response => {
        if (!response.ok) throw new Error('Runtime configuration is unavailable.');
        return response.json() as Promise<RuntimeConfig>;
      })
      .then(async runtimeConfig => {
        if (!active) return;
        setConfig(runtimeConfig);
        if (runtimeConfig.auth.provider !== 'none' && runtimeConfig.auth.authority && runtimeConfig.auth.clientId) {
          const manager = createOidcManager(runtimeConfig, window.location.origin, window.localStorage);
          managerRef.current = manager;
          setUser(await manager.getUser());
        }
        if (runtimeConfig.enableDevAuth && localStorage.getItem(DEV_SESSION_KEY) === 'true') setSynthetic('dev');
        else if (runtimeConfig.enableGuestAuth && localStorage.getItem(GUEST_SESSION_KEY) === 'true') setSynthetic('guest');
      })
      .catch(error => console.error('[AuthProvider] initialization failed', error))
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const login = useCallback(async () => {
    if (!managerRef.current) throw new Error('OIDC authentication is not configured.');
    await managerRef.current.signinRedirect();
  }, []);

  const completeLogin = useCallback(async () => {
    if (!managerRef.current) throw new Error('OIDC authentication is not configured.');
    setUser(await managerRef.current.signinRedirectCallback());
  }, []);

  const loginAsDev = useCallback(() => {
    if (!config?.enableDevAuth) return;
    localStorage.setItem(DEV_SESSION_KEY, 'true');
    localStorage.removeItem(GUEST_SESSION_KEY);
    setSynthetic('dev');
  }, [config]);

  const loginAsGuest = useCallback(() => {
    if (!config?.enableGuestAuth) return;
    localStorage.setItem(GUEST_SESSION_KEY, 'true');
    localStorage.removeItem(DEV_SESSION_KEY);
    setSynthetic('guest');
  }, [config]);

  const logout = useCallback(async () => {
    localStorage.removeItem(DEV_SESSION_KEY);
    localStorage.removeItem(GUEST_SESSION_KEY);
    if (synthetic) {
      setSynthetic(null);
      router.replace('/');
      return;
    }
    if (managerRef.current) {
      if (config?.auth.provider === 'cognito' && config.auth.logoutEndpoint) {
        await managerRef.current.removeUser();
        window.location.replace(createCognitoLogoutUrl(config, window.location.origin));
        return;
      }
      try {
        await managerRef.current.signoutRedirect();
        return;
      } catch (error) {
        console.warn('[AuthProvider] provider logout redirect failed', error);
        await managerRef.current.removeUser();
      }
    }
    setUser(null);
    router.replace('/');
  }, [config, router, synthetic]);

  const getAccessToken = useCallback(async () => {
    if (synthetic) return null;
    const currentUser = managerRef.current ? await managerRef.current.getUser() : user;
    return currentUser?.access_token ?? null;
  }, [synthetic, user]);

  const account = useMemo<AuthAccount | null>(() => {
    if (synthetic === 'dev') return { name: 'Dev User', email: 'dev@localhost', identityProvider: 'dev', synthetic };
    if (synthetic === 'guest') return { name: 'Guest User', email: 'guest@demo', identityProvider: 'guest', synthetic };
    return user && !user.expired ? accountFromUser(user) : null;
  }, [synthetic, user]);

  return useMemo(() => ({
    loading, config, account, isAuthenticated: account !== null, login, loginAsDev, loginAsGuest,
    logout, completeLogin, getAccessToken,
  }), [loading, config, account, login, loginAsDev, loginAsGuest, logout, completeLogin, getAccessToken]);
}
