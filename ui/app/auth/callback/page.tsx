'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/components/auth-provider';

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
    <main className="centered-page">
      {error ? <div className="notice error">{error}</div> : <div className="spinner" aria-label="Completing sign-in" />}
    </main>
  );
}
