'use client';

import { createContext, useContext, type ReactNode } from 'react';
import { useAuthSession, type AuthSession } from '@/hooks/useAuthSession';

const AuthContext = createContext<AuthSession | null>(null);

/** Provides the current authentication session to the component tree. */
export function AuthProvider({ children }: { readonly children: ReactNode }) {
  return <AuthContext.Provider value={useAuthSession()}>{children}</AuthContext.Provider>;
}

/** Returns the current authentication session. */
export function useAuth(): AuthSession {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used inside AuthProvider.');
  return value;
}
