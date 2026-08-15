import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Model } from '@/lib/types';
import ModelsPage from './page';

const mocks = vi.hoisted(() => {
  const archiveModel = vi.fn();
  const getModels = vi.fn();
  return { api: { archiveModel, getModels }, archiveModel, getModels, push: vi.fn() };
});

vi.mock('next/navigation', () => ({
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
  mocks.getModels.mockResolvedValue({ items: [model], page: 1, pageSize: 20, totalCount: 1 });
  mocks.archiveModel.mockResolvedValue(undefined);
});

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
  vi.unstubAllGlobals();
});

describe('ModelsPage', () => {
  it('preserves the model list as a styled table', async () => {
    render(<ModelsPage />);

    const table = await screen.findByRole('table');
    expect(table).toHaveClass('w-full', 'border-collapse');
    expect(screen.getAllByRole('columnheader').map(header => header.textContent)).toEqual([
      'Name', 'Status', 'Version', 'Created By', 'Updated', 'Actions',
    ]);
    expect(screen.getByText('Demand Forecast')).toBeInTheDocument();
    expect(screen.getByText('v3')).toBeInTheDocument();
    expect(screen.getByText('1 total model')).toBeInTheDocument();
  });

  it('filters through the API and resets pagination', async () => {
    render(<ModelsPage />);
    await screen.findByText('Demand Forecast');

    fireEvent.click(screen.getByRole('button', { name: 'Active' }));

    await waitFor(() => expect(mocks.getModels).toHaveBeenLastCalledWith(1, 20, 'Active'));

    fireEvent.click(screen.getByRole('button', { name: 'Active' }));

    await waitFor(() => expect(mocks.getModels).toHaveBeenLastCalledWith(1, 20, undefined));
    expect(screen.getByRole('button', { name: 'All' })).toHaveClass('bg-primary-soft');
  });

  it('archives from the action without navigating the row', async () => {
    vi.stubGlobal('confirm', vi.fn(() => true));
    render(<ModelsPage />);
    const archive = await screen.findByRole('button', { name: 'Archive Demand Forecast' });

    fireEvent.click(archive);

    await waitFor(() => expect(mocks.archiveModel).toHaveBeenCalledWith('model-1'));
    expect(mocks.push).not.toHaveBeenCalled();
  });

  it('restores All after two immediate clicks on the same status', async () => {
    render(<ModelsPage />);
    await screen.findByText('Demand Forecast');
    const archived = screen.getByRole('button', { name: 'Archived' });

    act(() => {
      archived.click();
      archived.click();
    });

    await waitFor(() => expect(mocks.getModels).toHaveBeenLastCalledWith(1, 20, undefined));
    expect(screen.getByRole('button', { name: 'All' })).toHaveClass('bg-primary-soft');
  });
});
