'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { ArrowLeft } from 'lucide-react';
import { Histogram } from '@/components/histogram';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelRunDetail } from '@/lib/types';

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

  return <div className="page"><div className="page-header"><h1>Run Detail</h1><Link className="button secondary" href={`/models/${id}/runs`}><ArrowLeft size={17} /> Back to Runs</Link></div>
    {error && <ErrorNotice message={error} />}
    <section className="card"><div className="card-header"><h2>Run Information</h2></div><div className="card-body"><dl className="detail-list">
      <div className="detail-row"><dt>Status</dt><dd><StatusBadge status={run.status} /></dd></div><div className="detail-row"><dt>Requested</dt><dd>{formatDate(run.requestedAtUtc)}</dd></div><div className="detail-row"><dt>Started</dt><dd>{formatDate(run.startedAtUtc)}</dd></div><div className="detail-row"><dt>Completed</dt><dd>{formatDate(run.completedAtUtc)}</dd></div>{run.errorMessage && <div className="detail-row"><dt>Error</dt><dd className="notice error">{run.errorMessage}</dd></div>}
    </dl></div></section>
    {run.metrics.length > 0 && <section className="card"><div className="card-header"><h2>Computed Metrics</h2></div><div className="table-wrap"><table><thead><tr><th>Metric</th><th>Value</th><th>Calculated</th></tr></thead><tbody>{run.metrics.map(metric => <tr key={metric.id}><td>{metric.metricName}</td><td>{metric.metricValue.toLocaleString('en-US', { maximumFractionDigits: 6 })}</td><td>{formatDate(metric.calculatedAtUtc)}</td></tr>)}</tbody></table></div></section>}
    {run.sampleData && <section className="card"><div className="card-header"><h2>Distribution</h2><span className="spacer" /><span className="muted">{run.sampleData.sampleSize.toLocaleString()} samples</span></div><div className="card-body"><Histogram data={run.sampleData} /></div></section>}
    {run.resultSummary && <section className="card"><div className="card-header"><h2>Result Summary</h2></div><div className="card-body"><pre className="json-display">{JSON.stringify(run.resultSummary, null, 2)}</pre></div></section>}
  </div>;
}
