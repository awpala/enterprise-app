import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import RunsPage from './page';

const mocks = vi.hoisted(() => {
  const getAllRuns = vi.fn();
  return { api: { getAllRuns }, getAllRuns, push: vi.fn() };
});

vi.mock('next/navigation', () => ({
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/lib/use-api', () => ({
  useApi: () => mocks.api,
}));

beforeEach(() => {
  mocks.getAllRuns.mockResolvedValue({ items: [], page: 1, pageSize: 20, totalCount: 0 });
});

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

describe('RunsPage', () => {
  it('toggles an active status filter back to All', async () => {
    render(<RunsPage />);
    await screen.findByText('No runs found.');
    expect(screen.getByText('0 total runs')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Completed' }));
    await waitFor(() => expect(mocks.getAllRuns).toHaveBeenLastCalledWith(1, 20, 'Completed'));

    fireEvent.click(screen.getByRole('button', { name: 'Completed' }));
    await waitFor(() => expect(mocks.getAllRuns).toHaveBeenLastCalledWith(1, 20, undefined));
    expect(screen.getByRole('button', { name: 'All' })).toHaveClass('bg-primary-soft');
  });
});
