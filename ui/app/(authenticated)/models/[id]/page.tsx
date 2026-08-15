'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, Edit3, Play } from 'lucide-react';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { Model, ModelRun } from '@/lib/types';

export default function ModelDetailPage() {
  const { id } = useParams<{ id: string }>();
  const api = useApi();
  const router = useRouter();
  const [model, setModel] = useState<Model | null>(null);
  const [runs, setRuns] = useState<ModelRun[]>([]);
  const [loading, setLoading] = useState(true);
  const [requesting, setRequesting] = useState(false);
  const [error, setError] = useState('');

  const loadRuns = useCallback(async () => {
    if (!api) return;
    const result = await api.getRuns(id);
    setRuns(result.slice(0, 5));
  }, [api, id]);

  useEffect(() => {
    if (!api) return;
    void Promise.all([api.getModel(id), api.getRuns(id)])
      .then(([loadedModel, loadedRuns]) => { setModel(loadedModel); setRuns(loadedRuns.slice(0, 5)); })
      .catch(reason => setError(errorMessage(reason)))
      .finally(() => setLoading(false));
  }, [api, id]);

  useEffect(() => {
    if (!runs.some(run => run.status === 'Pending' || run.status === 'Running')) return;
    const timer = window.setInterval(() => void loadRuns().catch(reason => setError(errorMessage(reason))), 5000);
    return () => window.clearInterval(timer);
  }, [runs, loadRuns]);

  const requestRun = async () => {
    if (!api) return;
    setRequesting(true);
    try { await api.requestRun(id); await loadRuns(); }
    catch (reason) { setError(errorMessage(reason)); }
    finally { setRequesting(false); }
  };

  if (loading) return <Loading label="Loading model" />;
  if (!model) return <ErrorNotice message={error || 'Model not found.'} />;

  return (
    <div className="page">
      <div className="page-header"><h1>{model.name}</h1><div className="header-actions">
        <Link className="button secondary" href="/models"><ArrowLeft size={17} /> Back</Link>
        <Link className="button secondary" href={`/models/${id}/edit`}><Edit3 size={17} /> Edit</Link>
        <button className="button primary" disabled={model.status === 'Archived' || requesting} onClick={() => void requestRun()}><Play size={17} /> {requesting ? 'Requesting…' : 'Run Model'}</button>
      </div></div>
      {error && <ErrorNotice message={error} />}
      <div className="card-grid">
        <section className="card"><div className="card-header"><h2>Details</h2></div><div className="card-body"><dl className="detail-list">
          <div className="detail-row"><dt>Status</dt><dd><StatusBadge status={model.status} /></dd></div>
          <div className="detail-row"><dt>Version</dt><dd>v{model.version}</dd></div>
          <div className="detail-row"><dt>Created</dt><dd>{formatDate(model.createdAtUtc)}</dd></div>
          <div className="detail-row"><dt>Updated</dt><dd>{formatDate(model.updatedAtUtc)}</dd></div>
          <div className="detail-row"><dt>Created By</dt><dd>{model.createdBy}</dd></div>
        </dl></div></section>
        <section className="card"><div className="card-header"><h2>Description</h2></div><div className="card-body"><p>{model.description || 'No description provided.'}</p></div></section>
      </div>
      {model.parameters && <section className="card"><div className="card-header"><h2>Parameters</h2></div><div className="card-body"><pre className="json-display">{JSON.stringify(model.parameters, null, 2)}</pre></div></section>}
      <section className="card"><div className="card-header"><h2>Recent Runs</h2><span className="spacer" /><Link className="button ghost" href={`/models/${id}/runs`}>View All</Link></div>
        {runs.length === 0 ? <div className="empty-state"><p>No runs yet.</p></div> : <div className="table-wrap"><table><thead><tr><th>Status</th><th>Requested</th><th>Completed</th></tr></thead><tbody>
          {runs.map(run => <tr className="clickable-row" key={run.id} onClick={() => router.push(`/models/${id}/runs/${run.id}`)}><td><StatusBadge status={run.status} /></td><td>{formatDate(run.requestedAtUtc, 'short')}</td><td>{formatDate(run.completedAtUtc, 'short')}</td></tr>)}
        </tbody></table></div>}
      </section>
    </div>
  );
}
