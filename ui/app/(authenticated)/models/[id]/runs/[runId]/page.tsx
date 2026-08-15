'use client';

import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Histogram } from '@/components/Histogram';
import { Loading } from '@/components/Loading';
import { StatusBadge } from '@/components/StatusBadge';
import { ButtonLink } from '@/components/ui/Button';
import { Card, CardBody, CardHeader } from '@/components/ui/Card';
import { DataTable, type DataTableColumn } from '@/components/ui/DataTable';
import { Page, PageHeader } from '@/components/ui/Page';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelMetric, ModelRunDetail } from '@/lib/types';

const metricColumns: readonly DataTableColumn<ModelMetric>[] = [
  { id: 'metric', header: 'Metric', cell: metric => metric.metricName },
  { id: 'value', header: 'Value', cell: metric => metric.metricValue.toLocaleString('en-US', { maximumFractionDigits: 6 }) },
  { id: 'calculated', header: 'Calculated', cell: metric => formatDate(metric.calculatedAtUtc) },
];

/** Renders one model run with lifecycle timestamps, metrics, and histogram data. */
export default function RunDetailPage() {
  const { id, runId } = useParams<{ id: string; runId: string }>();
  const api = useApi();
  const [run, setRun] = useState<ModelRunDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!api) return;
    void api.getRun(id, runId)
      .then(setRun)
      .catch(reason => setError(errorMessage(reason)))
      .finally(() => setLoading(false));
  }, [api, id, runId]);

  if (loading) return <Loading label="Loading run" />;
  if (!run) return <ErrorNotice message={error || 'Run not found.'} />;

  return (
    <Page>
      <PageHeader>
        <h1>Run Detail</h1>
        <ButtonLink variant="secondary" href={`/models/${id}/runs`}><ArrowLeft size={17} /> Back to Runs</ButtonLink>
      </PageHeader>
      {error && <ErrorNotice message={error} />}
      <div className="grid gap-[18px]">
        <Card>
          <CardHeader><h2>Run Information</h2></CardHeader>
          <CardBody>
            <dl className="grid gap-3">
              <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Status</dt><dd className="m-0"><StatusBadge status={run.status} /></dd></div>
              <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Requested</dt><dd className="m-0">{formatDate(run.requestedAtUtc)}</dd></div>
              <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Started</dt><dd className="m-0">{formatDate(run.startedAtUtc)}</dd></div>
              <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Completed</dt><dd className="m-0">{formatDate(run.completedAtUtc)}</dd></div>
              {run.errorMessage && <div className="grid grid-cols-[130px_1fr] items-center gap-4"><dt className="font-bold text-muted">Error</dt><dd className="m-0 rounded-[9px] border border-danger/30 bg-danger/10 px-[14px] py-3 text-danger">{run.errorMessage}</dd></div>}
            </dl>
          </CardBody>
        </Card>
        {run.metrics.length > 0 && (
          <Card>
            <CardHeader><h2>Computed Metrics</h2></CardHeader>
            <DataTable ariaLabel="Computed metrics" columns={metricColumns} rowKey={metric => metric.id} rows={run.metrics} />
          </Card>
        )}
        {run.sampleData && (
          <Card>
            <CardHeader><h2>Distribution</h2><span className="flex-1" /><span className="text-muted">{run.sampleData.sampleSize.toLocaleString()} samples</span></CardHeader>
            <CardBody><Histogram data={run.sampleData} /></CardBody>
          </Card>
        )}
        {run.resultSummary && (
          <Card>
            <CardHeader><h2>Result Summary</h2></CardHeader>
            <CardBody><pre className="m-0 overflow-auto rounded-[9px] bg-surface-muted p-[15px] text-xs text-foreground">{JSON.stringify(run.resultSummary, null, 2)}</pre></CardBody>
          </Card>
        )}
      </div>
    </Page>
  );
}
