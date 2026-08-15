import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Model } from '@/lib/types';
import ModelDetailPage from './page';

const mocks = vi.hoisted(() => {
  const getModel = vi.fn();
  const getRuns = vi.fn();
  const requestRun = vi.fn();
  return { api: { getModel, getRuns, requestRun }, getModel, getRuns, requestRun, push: vi.fn() };
});

vi.mock('next/navigation', () => ({
  useParams: () => ({ id: 'model-1' }),
  useRouter: () => ({ push: mocks.push }),
}));

vi.mock('@/lib/use-api', () => ({
  useApi: () => mocks.api,
}));

const model: Model = {
  id: 'model-1',
  name: 'Demand Forecast',
  description: 'Forecast demand.',
  status: 'Active',
  version: 3,
  parameters: null,
  createdAtUtc: '2026-08-01T12:00:00Z',
  updatedAtUtc: '2026-08-02T12:00:00Z',
  createdBy: 'Dev User',
};

beforeEach(() => {
  mocks.getModel.mockResolvedValue(model);
  mocks.getRuns.mockResolvedValue([]);
  mocks.requestRun.mockResolvedValue({
    id: 'run-1',
    modelId: model.id,
    status: 'Pending',
    requestedAtUtc: '2026-08-15T21:00:00Z',
    startedAtUtc: null,
    completedAtUtc: null,
    errorMessage: null,
  });
});

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

describe('ModelDetailPage', () => {
  it('renders equal-height detail and description cards', async () => {
    render(<ModelDetailPage />);

    const detailsCard = (await screen.findByRole('heading', { name: 'Details' })).closest('section');
    const descriptionCard = screen.getByRole('heading', { name: 'Description' }).closest('section');
    const grid = detailsCard?.parentElement;

    expect(detailsCard).toHaveClass('h-full');
    expect(descriptionCard).toHaveClass('h-full');
    expect(grid).toHaveClass('auto-rows-fr', 'items-stretch');
  });

  it('requests a run and refreshes the recent runs without leaving the model page', async () => {
    render(<ModelDetailPage />);

    fireEvent.click(await screen.findByRole('button', { name: 'Run Model' }));

    await waitFor(() => expect(mocks.requestRun).toHaveBeenCalledWith(model.id));
    await waitFor(() => expect(mocks.getRuns).toHaveBeenCalledTimes(2));
    expect(screen.getByRole('button', { name: 'Run Model' })).toBeEnabled();
  });

  it('submits at most one run request while the first request is in flight', async () => {
    let resolveRequest!: (value: Awaited<ReturnType<typeof mocks.requestRun>>) => void;
    mocks.requestRun.mockImplementationOnce(() => new Promise(resolve => { resolveRequest = resolve; }));
    render(<ModelDetailPage />);

    const runButton = await screen.findByRole('button', { name: 'Run Model' });
    fireEvent.click(runButton);
    fireEvent.click(runButton);

    expect(mocks.requestRun).toHaveBeenCalledTimes(1);
    resolveRequest({
      id: 'run-1',
      modelId: model.id,
      status: 'Pending',
      requestedAtUtc: '2026-08-15T21:00:00Z',
      startedAtUtc: null,
      completedAtUtc: null,
      errorMessage: null,
    });
    await waitFor(() => expect(runButton).toBeEnabled());
  });
});
