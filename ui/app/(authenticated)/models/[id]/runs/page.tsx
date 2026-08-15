'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, Play } from 'lucide-react';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelRun } from '@/lib/types';

export default function ModelRunsPage() {
  const { id } = useParams<{ id: string }>();
  const api = useApi();
  const router = useRouter();
  const [runs, setRuns] = useState<ModelRun[]>([]);
  const [loading, setLoading] = useState(true);
  const [requesting, setRequesting] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    if (!api) return;
    try { setRuns(await api.getRuns(id)); }
    catch (reason) { setError(errorMessage(reason)); }
    finally { setLoading(false); }
  }, [api, id]);

  useEffect(() => { void load(); }, [load]);
  useEffect(() => {
    if (!runs.some(run => run.status === 'Pending' || run.status === 'Running')) return;
    const timer = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(timer);
  }, [runs, load]);

  const request = async () => {
    if (!api) return;
    setRequesting(true);
    try { await api.requestRun(id); await load(); }
    catch (reason) { setError(errorMessage(reason)); }
    finally { setRequesting(false); }
  };

  return <div className="page"><div className="page-header"><h1>Model Runs</h1><div className="header-actions"><Link className="button secondary" href={`/models/${id}`}><ArrowLeft size={17} /> Back to Model</Link><button className="button primary" disabled={requesting} onClick={() => void request()}><Play size={17} /> New Run</button></div></div>
    {error && <ErrorNotice message={error} />}{loading ? <Loading label="Loading runs" /> : runs.length === 0 ? <div className="empty-state"><p>No runs yet.</p></div> : <section className="card"><div className="table-wrap"><table><thead><tr><th>Status</th><th>Requested</th><th>Started</th><th>Completed</th><th>Error</th></tr></thead><tbody>
      {runs.map(run => <tr className="clickable-row" key={run.id} onClick={() => router.push(`/models/${id}/runs/${run.id}`)}><td><StatusBadge status={run.status} /></td><td>{formatDate(run.requestedAtUtc)}</td><td>{formatDate(run.startedAtUtc)}</td><td>{formatDate(run.completedAtUtc)}</td><td className="truncate">{run.errorMessage}</td></tr>)}
    </tbody></table></div></section>}
  </div>;
}
