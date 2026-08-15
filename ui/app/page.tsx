'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Cloud, Code2, LogIn, UserRound } from 'lucide-react';
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
        <div className="brand-mark"><Cloud size={36} /></div>
        <p className="eyebrow">Cloud-neutral reference platform</p>
        <h1>Enterprise App</h1>
        <p className="lead">Model-driven workflows, asynchronous job processing, and portable observability.</p>
        {auth.loading && <div className="spinner" aria-label="Loading authentication" />}
        {!auth.loading && auth.config?.auth.provider !== 'none' && (
          <button className="button primary wide" onClick={() => void auth.login()}>
            <LogIn size={18} /> Sign in with SSO
          </button>
        )}
        {!auth.loading && auth.config?.enableDevAuth && (
          <button className="button secondary wide" onClick={enterAsDev}>
            <Code2 size={18} /> Log in as Dev
          </button>
        )}
        {!auth.loading && auth.config?.enableGuestAuth && (
          <button className="button secondary wide" onClick={enterAsGuest}>
            <UserRound size={18} /> Log in as Guest
          </button>
        )}
        {!auth.loading && auth.config && (
          <p className="config-hint">
            Deployment target: <strong>{auth.config.deploymentTarget}</strong>
            {' · '}Identity: <strong>{auth.config.auth.provider}</strong>
          </p>
        )}
      </section>
    </main>
  );
}
