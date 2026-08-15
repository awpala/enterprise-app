'use client';

import { usePathname, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { useMediaQuery } from '@/hooks/useMediaQuery';
import { ApplicationHeader } from './ApplicationHeader';
import { ApplicationNavigation } from './ApplicationNavigation';
import { useAuth } from './AuthProvider';
import { Spinner } from './Spinner';
import { useTheme } from './ThemeProvider';

const DESKTOP_NAVIGATION_QUERY = '(min-width: 640px)';

/** Guards authenticated routes and renders the shared application chrome. */
export function AppShell({ children }: { readonly children: ReactNode }) {
  const auth = useAuth();
  const { theme, toggleTheme } = useTheme();
  const pathname = usePathname();
  const router = useRouter();
  const desktopViewport = useMediaQuery(DESKTOP_NAVIGATION_QUERY);
  const [desktopMenuOpen, setDesktopMenuOpen] = useState(true);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const menuOpen = desktopViewport ? desktopMenuOpen : mobileMenuOpen;

  useEffect(() => {
    if (!auth.loading && !auth.isAuthenticated) router.replace('/');
  }, [auth.loading, auth.isAuthenticated, router]);

  useEffect(() => {
    if (!desktopViewport) setMobileMenuOpen(false);
  }, [desktopViewport, pathname]);

  const closeMobileNavigation = useCallback(() => {
    if (!desktopViewport) setMobileMenuOpen(false);
  }, [desktopViewport]);

  const toggleNavigation = useCallback(() => {
    if (desktopViewport) setDesktopMenuOpen(value => !value);
    else setMobileMenuOpen(value => !value);
  }, [desktopViewport]);

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
        onMenuToggle={toggleNavigation}
        onThemeToggle={toggleTheme}
        theme={theme}
      />
      <div className="flex min-h-0 flex-1">
        {menuOpen && (
          <>
            <button
              aria-label="Close navigation"
              className="fixed inset-x-0 bottom-0 top-16 z-20 bg-black/35 sm:hidden"
              onClick={closeMobileNavigation}
              type="button"
            />
            <ApplicationNavigation pathname={pathname} onNavigate={closeMobileNavigation} />
          </>
        )}
        <main className="min-h-0 min-w-0 flex-1 overflow-auto px-[14px] py-5 sm:p-[30px]">{children}</main>
      </div>
    </div>
  );
}
