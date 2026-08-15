'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Code2, LogIn, Network, UserRound } from 'lucide-react';
import { useAuth } from '@/components/auth-provider';

export default function LandingPage() {
  const router = useRouter();
  const auth = useAuth();

  useEffect(() => {
    if (auth.isAuthenticated) router.replace('/dashboard');
  }, [auth.isAuthenticated, router]);

  const enterAsDev = () => {
    auth.loginAsDev();
    router.push('/dashboard');
  };
  const enterAsGuest = () => {
    auth.loginAsGuest();
    router.push('/dashboard');
  };

  return (
    <main className="landing-shell">
      <section className="landing-card">
        <div className="brand-mark"><Network size={36} /></div>
        <h1>Enterprise App</h1>
        <p className="lead">Model-driven workflows, async job processing, and enterprise observability.</p>
        {auth.loading && <div className="spinner" aria-label="Loading authentication" />}
        {!auth.loading && auth.config?.auth.provider !== 'none' && (
          <button className="button primary wide" onClick={() => void auth.login()}>
            <LogIn size={18} /> Sign in
          </button>
        )}
        {!auth.loading && auth.config?.enableDevAuth && (
          <>
            <button className="button secondary wide" onClick={enterAsDev}>
              <Code2 size={18} /> Log in as Dev
            </button>
            <p className="config-hint">
              Non-production: the dev session is a synthetic principal matching the backend&apos;s
              DevAuthHandler sentinel. Not available in prod builds.
            </p>
          </>
        )}
        {!auth.loading && auth.config?.enableGuestAuth && (
          <>
            <button className="button secondary wide" onClick={enterAsGuest}>
              <UserRound size={18} /> Log in as Guest
            </button>
            <p className="config-hint">
              Demo access: the guest session is a synthetic principal with full read/write access,
              intended for sales and evaluation walkthroughs.
            </p>
          </>
        )}
        {!auth.loading && auth.config?.auth.provider === 'none'
          && !auth.config.enableDevAuth && !auth.config.enableGuestAuth && (
          <p className="config-hint">
            No sign-in is available: OIDC is unconfigured and dev/guest auth are disabled.
          </p>
        )}
      </section>
    </main>
  );
}
