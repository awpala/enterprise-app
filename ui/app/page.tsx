'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Code2, LogIn, Network, UserRound } from 'lucide-react';
import { useAuth } from '@/components/AuthProvider';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/Spinner';

/** Renders the public sign-in landing page and available authentication entry points. */
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
    <main className="grid min-h-screen place-items-center bg-background bg-[image:var(--app-backdrop)] p-6">
      <section className="flex w-full max-w-[520px] flex-col items-center gap-[14px] rounded-3xl border border-border bg-surface/95 p-6 text-center shadow-elevated sm:p-12">
        <div className="grid size-[68px] place-items-center rounded-[20px] bg-linear-to-br from-primary to-[#5d83ff] text-white">
          <Network size={36} />
        </div>
        <h1 className="m-0 text-[clamp(2rem,6vw,3.25rem)] leading-[1.05] font-bold tracking-[-0.04em]">
          Enterprise App
        </h1>
        <p className="mb-3 max-w-[42ch] text-muted">
          Model-driven workflows, async job processing, and enterprise observability.
        </p>
        {auth.loading && <Spinner label="Loading authentication" />}
        {!auth.loading && auth.config?.auth.provider !== 'none' && (
          <Button className="w-full max-w-[280px]" onClick={() => void auth.login()}>
            <LogIn size={18} /> Sign in
          </Button>
        )}
        {!auth.loading && auth.config?.enableDevAuth && (
          <>
            <Button className="w-full max-w-[280px]" variant="secondary" onClick={enterAsDev}>
              <Code2 size={18} /> Log in as Dev
            </Button>
            <p className="mt-2 text-xs text-muted">
              Non-production: the dev session is a synthetic principal matching the backend&apos;s
              DevAuthHandler sentinel. Not available in prod builds.
            </p>
          </>
        )}
        {!auth.loading && auth.config?.enableGuestAuth && (
          <>
            <Button className="w-full max-w-[280px]" variant="secondary" onClick={enterAsGuest}>
              <UserRound size={18} /> Log in as Guest
            </Button>
            <p className="mt-2 text-xs text-muted">
              Demo access: the guest session is a synthetic principal with full read/write access,
              intended for sales and evaluation walkthroughs.
            </p>
          </>
        )}
        {!auth.loading && auth.config?.auth.provider === 'none'
          && !auth.config.enableDevAuth && !auth.config.enableGuestAuth && (
          <p className="mt-2 text-xs text-muted">
            No sign-in is available: OIDC is unconfigured and dev/guest auth are disabled.
          </p>
        )}
      </section>
    </main>
  );
}
