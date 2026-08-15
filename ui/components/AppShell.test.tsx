import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AppShell } from './AppShell';

const mocks = vi.hoisted(() => ({
  logout: vi.fn(),
  pathname: '/dashboard',
  replace: vi.fn(),
  toggleTheme: vi.fn(),
}));

vi.mock('next/navigation', () => ({
  usePathname: () => mocks.pathname,
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
  mocks.pathname = '/dashboard';
  vi.clearAllMocks();
  vi.unstubAllGlobals();
});

function openNavigation() {
  const toggle = screen.getByRole('button', { name: 'Toggle navigation' });
  if (toggle.getAttribute('aria-expanded') === 'false') fireEvent.click(toggle);
  expect(toggle).toHaveAttribute('aria-expanded', 'true');
}

describe('AppShell', () => {
  it('renders navigation closed by default and uses the hamburger to open and close it', () => {
    render(<AppShell><p>Page content</p></AppShell>);

    const toggle = screen.getByRole('button', { name: 'Toggle navigation' });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(toggle.querySelector('.lucide-menu')).toBeInTheDocument();
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();

    fireEvent.click(toggle);

    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    expect(toggle.querySelector('.lucide-menu')).toBeInTheDocument();
    expect(screen.getByRole('navigation')).toBeInTheDocument();

    fireEvent.click(toggle);

    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('closes navigation when a navigation link is selected', () => {
    render(<AppShell><p>Page content</p></AppShell>);

    openNavigation();
    const modelsLink = screen.getByRole('link', { name: 'Models' });
    modelsLink.addEventListener('click', event => event.preventDefault(), { once: true });
    fireEvent.click(modelsLink);

    expect(screen.getByRole('button', { name: 'Toggle navigation' })).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('closes open navigation after the active route changes', () => {
    const { rerender } = render(<AppShell><p>Page content</p></AppShell>);
    openNavigation();

    mocks.pathname = '/runs';
    rerender(<AppShell><p>Page content</p></AppShell>);

    expect(screen.getByRole('button', { name: 'Toggle navigation' })).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('keeps desktop navigation open across routes and toggles it independently', () => {
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({
      addEventListener: vi.fn(),
      matches: true,
      removeEventListener: vi.fn(),
    }));
    render(<AppShell><p>Page content</p></AppShell>);

    const toggle = screen.getByRole('button', { name: 'Toggle navigation' });
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    const modelsLink = screen.getByRole('link', { name: 'Models' });
    modelsLink.addEventListener('click', event => event.preventDefault(), { once: true });
    fireEvent.click(modelsLink);
    expect(screen.getByRole('navigation')).toBeInTheDocument();

    fireEvent.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument();
  });

  it('keeps application chrome fixed while the route content owns scrolling', () => {
    render(<AppShell><p>Page content</p></AppShell>);
    openNavigation();

    const shell = screen.getByText('Page content').closest('div.h-dvh');
    const main = screen.getByRole('main');
    const header = screen.getByRole('banner');
    const navigation = screen.getByRole('navigation').closest('aside');

    expect(shell).toHaveClass('overflow-hidden');
    expect(header).toHaveClass('sticky', 'top-0', 'shrink-0');
    expect(main).toHaveClass('overflow-auto');
    expect(navigation).toHaveClass(
      'fixed',
      'bottom-0',
      'left-0',
      'top-16',
      'overflow-y-auto',
      'sm:relative',
      'sm:h-full',
    );
    expect(screen.getByRole('button', { name: 'Close navigation' })).toHaveClass(
      'fixed',
      'bottom-0',
      'top-16',
      'sm:hidden',
    );
  });
});
