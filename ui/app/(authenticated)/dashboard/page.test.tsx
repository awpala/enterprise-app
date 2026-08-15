import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import DashboardPage from './page';

const mocks = vi.hoisted(() => {
  const getModels = vi.fn();
  return { api: { getModels }, getModels, push: vi.fn() };
});

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/lib/use-api', () => ({
  useApi: () => mocks.api,
}));

beforeEach(() => {
  mocks.getModels.mockImplementation((_page: number, _pageSize: number, status?: string) => Promise.resolve({
    items: [],
    page: 1,
    pageSize: 5,
    totalCount: status === 'Active' ? 2 : 4,
  }));
});

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

describe('DashboardPage', () => {
  it('renders equal-height summary cards', async () => {
    render(<DashboardPage />);

    const totalLabel = await screen.findByText('Total Models');
    const activeLabel = screen.getByText('Active Models');
    const totalCard = totalLabel.parentElement?.parentElement;
    const activeCard = activeLabel.parentElement?.parentElement;
    const grid = totalCard?.parentElement;

    expect(totalCard).toHaveClass('h-full');
    expect(activeCard).toHaveClass('h-full');
    expect(grid).toHaveClass('auto-rows-fr', 'items-stretch');
    expect(screen.getByText('4')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
  });
});
