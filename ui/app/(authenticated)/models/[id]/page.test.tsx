import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Model } from '@/lib/types';
import ModelDetailPage from './page';

const mocks = vi.hoisted(() => {
  const getModel = vi.fn();
  const getRuns = vi.fn();
  return { api: { getModel, getRuns, requestRun: vi.fn() }, getModel, getRuns, push: vi.fn() };
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
});
