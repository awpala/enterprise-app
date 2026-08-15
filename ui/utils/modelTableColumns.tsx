import { Archive } from 'lucide-react';
import { IconButton } from '@/components/ui/Button';
import { StatusBadge } from '@/components/StatusBadge';
import type { DataTableColumn } from '@/components/ui/DataTable';
import { formatDate } from '@/lib/format';
import type { Model } from '@/lib/types';

interface ModelTableColumnOptions {
  readonly compact?: boolean;
  readonly onArchive?: (model: Model) => void;
}

/** Creates the shared model columns consumed by the generic data table. */
export function createModelTableColumns({ compact = false, onArchive }: ModelTableColumnOptions = {}): readonly DataTableColumn<Model>[] {
  return [
    { id: 'name', header: 'Name', cellClassName: 'font-semibold text-foreground', cell: model => model.name },
    { id: 'status', header: 'Status', cell: model => <StatusBadge status={model.status} /> },
    { id: 'version', header: 'Version', cell: model => `v${model.version}` },
    ...(!compact ? [{ id: 'createdBy', header: 'Created By', cell: (model: Model) => model.createdBy }] : []),
    { id: 'updated', header: 'Updated', cell: model => formatDate(model.updatedAtUtc, 'short') },
    ...(onArchive ? [{
      id: 'actions',
      header: <span className="sr-only">Actions</span>,
      headerClassName: 'w-14',
      cellClassName: 'w-14',
      cell: (model: Model) => (
        <IconButton
          aria-label={`Archive ${model.name}`}
          onClick={event => { event.stopPropagation(); onArchive(model); }}
        >
          <Archive size={18} />
        </IconButton>
      ),
    }] : []),
  ];
}
