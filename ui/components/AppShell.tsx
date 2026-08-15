'use client';

import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { ApplicationHeader } from './ApplicationHeader';
import { ApplicationNavigation } from './ApplicationNavigation';
import { useAuth } from './AuthProvider';
import { Spinner } from './Spinner';
import { useTheme } from './ThemeProvider';

export function AppShell({ children }: { readonly children: ReactNode }) {
  const auth = useAuth();
  const { theme, toggleTheme } = useTheme();
  const pathname = usePathname();
  const router = useRouter();
  const [menuOpen, setMenuOpen] = useState(true);

  useEffect(() => {
    if (!auth.loading && !auth.isAuthenticated) router.replace('/');
  }, [auth.loading, auth.isAuthenticated, router]);

  if (auth.loading || !auth.isAuthenticated) {
    return (
      <main className="grid min-h-screen place-items-center bg-background bg-[image:var(--app-backdrop)] p-6">
        <Spinner label="Loading session" />
      </main>
    );
  }

  return (
    <div className="flex h-dvh flex-col overflow-hidden">
      <ApplicationHeader
        accountName={auth.account?.name}
        deploymentTarget={auth.config?.deploymentTarget}
        identityProvider={auth.account?.identityProvider}
        menuOpen={menuOpen}
        onLogout={() => void auth.logout()}
        onMenuToggle={() => setMenuOpen(value => !value)}
        onThemeToggle={toggleTheme}
        theme={theme}
      />
      <div className="flex min-h-0 flex-1">
        {menuOpen && <ApplicationNavigation pathname={pathname} />}
        <main className="min-h-0 min-w-0 flex-1 overflow-auto px-[14px] py-5 sm:p-[30px]">{children}</main>
      </div>
    </div>
  );
}
