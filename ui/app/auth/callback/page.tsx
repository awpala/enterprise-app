'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/components/AuthProvider';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Spinner } from '@/components/Spinner';

/** Completes the browser OIDC redirect and returns to the authenticated dashboard. */
export default function AuthCallbackPage() {
  const { loading, completeLogin } = useAuth();
  const router = useRouter();
  const [error, setError] = useState('');

  useEffect(() => {
    if (loading) return;
    void completeLogin()
      .then(() => router.replace('/dashboard'))
      .catch(reason => setError(reason instanceof Error ? reason.message : 'Sign-in failed.'));
  }, [loading, completeLogin, router]);

  return (
    <main className="grid min-h-screen place-items-center bg-background bg-[image:var(--app-backdrop)] p-6">
      {error ? <ErrorNotice message={error} /> : <Spinner label="Completing sign-in" />}
    </main>
  );
}
