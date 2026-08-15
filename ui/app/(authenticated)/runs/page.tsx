'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { RefreshCw } from 'lucide-react';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelRunStatus, RunSummary } from '@/lib/types';

const options: Array<ModelRunStatus | 'All'> = ['All', 'Pending', 'Running', 'Completed', 'Failed'];

export default function RunsPage() {
  const api = useApi();
  const router = useRouter();
  const [runs, setRuns] = useState<RunSummary[]>([]);
  const [status, setStatus] = useState<ModelRunStatus | undefined>();
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const pageSize = 20;

  const load = useCallback(async () => {
    if (!api) return;
    setLoading(true);
    try {
      const result = await api.getAllRuns(page, pageSize, status);
      setRuns(result.items);
      setTotal(result.totalCount);
    } catch (reason) { setError(errorMessage(reason)); }
    finally { setLoading(false); }
  }, [api, page, status]);

  useEffect(() => { void load(); }, [load]);
  useEffect(() => {
    if (!runs.some(run => run.status === 'Pending' || run.status === 'Running')) return;
    const timer = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(timer);
  }, [runs, load]);

  return <div className="page"><div className="page-header"><h1>Runs</h1><button className="button secondary" onClick={() => void load()}><RefreshCw size={17} /> Refresh</button></div>
    <div className="filter-bar" role="group" aria-label="Status filter">{options.map(option => { const active = option === 'All' ? !status : status === option; return <button className={`chip ${active ? 'active' : ''}`} key={option} onClick={() => { setStatus(option === 'All' ? undefined : option); setPage(1); }}>{option}</button>; })}</div>
    {error && <ErrorNotice message={error} />}{loading ? <Loading label="Loading runs" /> : runs.length === 0 ? <div className="empty-state"><p>No runs found.</p></div> : <section className="card"><div className="table-wrap"><table><thead><tr><th>Status</th><th>Model</th><th>Requested</th><th>Started</th><th>Completed</th><th>Error</th></tr></thead><tbody>
      {runs.map(run => <tr className="clickable-row" key={run.id} onClick={() => router.push(`/models/${run.modelId}/runs/${run.id}`)}><td><StatusBadge status={run.status} /></td><td>{run.modelName}</td><td>{formatDate(run.requestedAtUtc)}</td><td>{formatDate(run.startedAtUtc)}</td><td>{formatDate(run.completedAtUtc)}</td><td className="truncate">{run.errorMessage}</td></tr>)}
    </tbody></table></div><div className="pagination"><button className="button secondary" disabled={page === 1} onClick={() => setPage(value => value - 1)}>Previous</button><span>Page {page} of {Math.max(1, Math.ceil(total / pageSize))}</span><button className="button secondary" disabled={page * pageSize >= total} onClick={() => setPage(value => value + 1)}>Next</button></div></section>}
  </div>;
}
