import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { DataTable, type DataTableColumn } from './DataTable';

interface Row {
  readonly id: string;
  readonly name: string;
}

const columns: readonly DataTableColumn<Row>[] = [
  { id: 'name', header: 'Name', cell: row => row.name },
];

afterEach(cleanup);

describe('DataTable', () => {
  it('renders typed columns and rows', () => {
    render(<DataTable ariaLabel="Examples" columns={columns} rowKey={row => row.id} rows={[{ id: '1', name: 'Example' }]} />);

    expect(screen.getByRole('table', { name: 'Examples' })).toBeInTheDocument();
    expect(screen.getByRole('table', { name: 'Examples' }).parentElement).toHaveClass('mb-4', 'min-h-0', 'shrink', 'overflow-auto');
    expect(screen.getByRole('columnheader', { name: 'Name' })).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: 'Example' })).toBeInTheDocument();
  });

  it('supports mouse and keyboard row activation', () => {
    const activate = vi.fn();
    render(<DataTable columns={columns} onRowActivate={activate} rowKey={row => row.id} rows={[{ id: '1', name: 'Example' }]} />);
    const row = screen.getByRole('row', { name: 'Example' });

    fireEvent.click(row);
    fireEvent.keyDown(row, { key: 'Enter' });

    expect(activate).toHaveBeenCalledTimes(2);
  });
});
