'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { Github, LayoutDashboard, LogOut, Menu, Moon, PlayCircle, Sun, TestTube2, X } from 'lucide-react';
import { DARK_THEME } from '@/lib/theme';
import { useAuth } from './auth-provider';
import { useTheme } from './theme-provider';

const navigation = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/models', label: 'Models', icon: TestTube2 },
  { href: '/runs', label: 'Runs', icon: PlayCircle },
] as const;

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
    return <main className="centered-page"><div className="spinner" aria-label="Loading session" /></main>;
  }

  return (
    <div className="app-frame">
      <header className="topbar">
        <button className="icon-button" onClick={() => setMenuOpen(value => !value)} aria-label="Toggle navigation">
          {menuOpen ? <X /> : <Menu />}
        </button>
        <Link href="/dashboard" className="topbar-brand">Enterprise App</Link>
        <span className="topbar-spacer" />
        <span className="target-pill">{auth.config?.deploymentTarget}</span>
        <button className="icon-button" onClick={toggleTheme} aria-label="Toggle theme">
          {theme === DARK_THEME ? <Sun /> : <Moon />}
        </button>
        <a className="icon-button" href="https://github.com/awpala/enterprise-app" target="_blank" rel="noreferrer" aria-label="View source">
          <Github />
        </a>
        <div className="account-summary">
          <strong>{auth.account?.name}</strong>
          <small>{auth.account?.identityProvider}</small>
        </div>
        <button className="icon-button" onClick={() => void auth.logout()} aria-label="Sign out"><LogOut /></button>
      </header>
      <div className="body-frame">
        {menuOpen && (
          <aside className="sidebar">
            <nav>
              {navigation.map(item => {
                const Icon = item.icon;
                const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
                return (
                  <Link className={`nav-link ${active ? 'active' : ''}`} href={item.href} key={item.href}>
                    <Icon size={19} /> {item.label}
                  </Link>
                );
              })}
            </nav>
          </aside>
        )}
        <main className="content">{children}</main>
      </div>
    </div>
  );
}
