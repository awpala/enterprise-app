import { formatDate } from '@/lib/format';
import type { ModelRun, RunSummary } from '@/lib/types';
import { StatusBadge } from '../StatusBadge';
import { DataTable, type DataTableColumn } from '../ui/DataTable';

type RunsTableVariant = 'global' | 'model' | 'recent';

interface RunsTableProps {
  readonly onOpen: (run: ModelRun | RunSummary) => void;
  readonly runs: readonly (ModelRun | RunSummary)[];
  readonly variant: RunsTableVariant;
}

function isSummary(run: ModelRun | RunSummary): run is RunSummary {
  return 'modelName' in run;
}

/** Shared run listing table for global, per-model, and recent-run views. */
export function RunsTable({ onOpen, runs, variant }: RunsTableProps) {
  const showModel = variant === 'global';
  const compact = variant === 'recent';
  const columns: DataTableColumn<ModelRun | RunSummary>[] = [
    { id: 'status', header: 'Status', cell: run => <StatusBadge status={run.status} /> },
    ...(showModel ? [{ id: 'model', header: 'Model', cell: (run: ModelRun | RunSummary) => isSummary(run) ? run.modelName : '' }] : []),
    { id: 'requested', header: 'Requested', cell: run => formatDate(run.requestedAtUtc, compact ? 'short' : undefined) },
    ...(!compact ? [{ id: 'started', header: 'Started', cell: (run: ModelRun | RunSummary) => formatDate(run.startedAtUtc) }] : []),
    { id: 'completed', header: 'Completed', cell: run => formatDate(run.completedAtUtc, compact ? 'short' : undefined) },
    ...(!compact ? [{
      id: 'error',
      header: 'Error',
      cellClassName: 'max-w-[300px] overflow-hidden text-ellipsis',
      cell: (run: ModelRun | RunSummary) => run.errorMessage,
    }] : []),
  ];

  return <DataTable ariaLabel="Runs" columns={columns} onRowActivate={onOpen} rowKey={run => run.id} rows={runs} />;
}
