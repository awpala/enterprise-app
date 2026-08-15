'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import { UserManager, WebStorageStateStore, type User } from 'oidc-client-ts';
import { useRouter } from 'next/navigation';
import type { RuntimeConfig } from '@/lib/types';

const DEV_SESSION_KEY = 'ea:dev-session';
const GUEST_SESSION_KEY = 'ea:guest-session';

interface Account {
  readonly name: string;
  readonly email: string;
  readonly identityProvider: string;
  readonly synthetic: 'dev' | 'guest' | null;
}

interface AuthContextValue {
  readonly loading: boolean;
  readonly config: RuntimeConfig | null;
  readonly account: Account | null;
  readonly isAuthenticated: boolean;
  readonly login: () => Promise<void>;
  readonly loginAsDev: () => void;
  readonly loginAsGuest: () => void;
  readonly logout: () => Promise<void>;
  readonly completeLogin: () => Promise<void>;
  readonly getAccessToken: () => Promise<string | null>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function accountFromUser(user: User): Account {
  const profile = user.profile;
  const identities = profile.identities;
  let identityProvider = 'email';
  if (typeof profile.idp === 'string') identityProvider = profile.idp;
  if (typeof identities === 'string') {
    try {
      const parsed = JSON.parse(identities) as Array<{ providerName?: string }>;
      identityProvider = parsed[0]?.providerName ?? identityProvider;
    } catch {
      // Optional display metadata does not affect the authenticated session.
    }
  }
  return {
    name: typeof profile.name === 'string'
      ? profile.name
      : typeof profile.preferred_username === 'string'
        ? profile.preferred_username
        : 'Signed-in user',
    email: typeof profile.email === 'string'
      ? profile.email
      : typeof profile.preferred_username === 'string'
        ? profile.preferred_username
        : '',
    identityProvider,
    synthetic: null,
  };
}

export function AuthProvider({ children }: { readonly children: ReactNode }) {
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
        if (runtimeConfig.auth.provider !== 'none'
            && runtimeConfig.auth.authority
            && runtimeConfig.auth.clientId) {
          const manager = new UserManager({
            authority: runtimeConfig.auth.authority,
            client_id: runtimeConfig.auth.clientId,
            redirect_uri: `${window.location.origin}/auth/callback`,
            post_logout_redirect_uri: `${window.location.origin}/`,
            response_type: 'code',
            scope: `openid profile email ${runtimeConfig.auth.apiScope}`.trim(),
            automaticSilentRenew: true,
            userStore: new WebStorageStateStore({ store: window.localStorage }),
          });
          managerRef.current = manager;
          setUser(await manager.getUser());
        }

        if (runtimeConfig.enableDevAuth && localStorage.getItem(DEV_SESSION_KEY) === 'true') {
          setSynthetic('dev');
        } else if (runtimeConfig.enableGuestAuth && localStorage.getItem(GUEST_SESSION_KEY) === 'true') {
          setSynthetic('guest');
        }
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
    const completedUser = await managerRef.current.signinRedirectCallback();
    setUser(completedUser);
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
        const endpoint = new URL('/logout', config.auth.logoutEndpoint);
        endpoint.searchParams.set('client_id', config.auth.clientId);
        endpoint.searchParams.set('logout_uri', window.location.origin);
        window.location.replace(endpoint);
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

  const account = useMemo<Account | null>(() => {
    if (synthetic === 'dev') {
      return { name: 'Dev User', email: 'dev@localhost', identityProvider: 'dev', synthetic };
    }
    if (synthetic === 'guest') {
      return { name: 'Guest User', email: 'guest@demo', identityProvider: 'guest', synthetic };
    }
    return user && !user.expired ? accountFromUser(user) : null;
  }, [synthetic, user]);

  const value = useMemo<AuthContextValue>(() => ({
    loading,
    config,
    account,
    isAuthenticated: account !== null,
    login,
    loginAsDev,
    loginAsGuest,
    logout,
    completeLogin,
    getAccessToken,
  }), [loading, config, account, login, loginAsDev, loginAsGuest, logout, completeLogin, getAccessToken]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider.');
  return value;
}
