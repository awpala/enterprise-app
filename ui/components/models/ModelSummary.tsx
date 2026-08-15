import type { Model } from '@/lib/types';
import { formatDate } from '@/lib/format';
import { StatusBadge } from '../StatusBadge';
import { Card, CardBody, CardHeader } from '../ui/Card';

/** Equal-height model metadata and description cards. */
export function ModelSummary({ model }: { readonly model: Model }) {
  return (
    <div className="mb-[18px] grid auto-rows-fr grid-cols-1 items-stretch gap-4 sm:grid-cols-2">
      <Card className="h-full">
        <CardHeader><h2>Details</h2></CardHeader>
        <CardBody>
          <dl className="grid gap-3">
            <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Status</dt><dd className="m-0"><StatusBadge status={model.status} /></dd></div>
            <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Version</dt><dd className="m-0">v{model.version}</dd></div>
            <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Created</dt><dd className="m-0">{formatDate(model.createdAtUtc)}</dd></div>
            <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Updated</dt><dd className="m-0">{formatDate(model.updatedAtUtc)}</dd></div>
            <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Created By</dt><dd className="m-0">{model.createdBy}</dd></div>
          </dl>
        </CardBody>
      </Card>
      <Card className="h-full">
        <CardHeader><h2>Description</h2></CardHeader>
        <CardBody><p>{model.description || 'No description provided.'}</p></CardBody>
      </Card>
    </div>
  );
}
