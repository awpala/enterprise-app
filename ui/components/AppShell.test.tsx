import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AppShell } from './AppShell';

const mocks = vi.hoisted(() => ({
  logout: vi.fn(),
  replace: vi.fn(),
  toggleTheme: vi.fn(),
}));

vi.mock('next/navigation', () => ({
  usePathname: () => '/dashboard',
  useRouter: () => ({ replace: mocks.replace }),
}));

vi.mock('./AuthProvider', () => ({
  useAuth: () => ({
    account: { name: 'Dev User', identityProvider: 'dev' },
    config: { deploymentTarget: 'local' },
    isAuthenticated: true,
    loading: false,
    logout: mocks.logout,
  }),
}));

vi.mock('./ThemeProvider', () => ({
  useTheme: () => ({ theme: 'light', toggleTheme: mocks.toggleTheme }),
}));

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

describe('AppShell', () => {
  it('uses the same hamburger button to open and close navigation', () => {
    render(<AppShell><p>Page content</p></AppShell>);

    const toggle = screen.getByRole('button', { name: 'Toggle navigation' });
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    expect(toggle.querySelector('.lucide-menu')).toBeInTheDocument();
    expect(screen.getByRole('navigation')).toBeInTheDocument();

    fireEvent.click(toggle);

    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(toggle.querySelector('.lucide-menu')).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });
});
