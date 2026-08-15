'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { Archive, Plus } from 'lucide-react';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { errorMessage, formatDate } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { Model, ModelStatus } from '@/lib/types';

const statusOptions: Array<ModelStatus | 'All'> = ['All', 'Draft', 'Active', 'Archived'];

export default function ModelsPage() {
  const api = useApi();
  const router = useRouter();
  const [models, setModels] = useState<Model[]>([]);
  const [status, setStatus] = useState<ModelStatus | undefined>();
  const [page, setPage] = useState(1);
  const [pageSize] = useState(20);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    if (!api) return;
    setLoading(true);
    setError('');
    try {
      const result = await api.getModels(page, pageSize, status);
      setModels(result.items);
      setTotal(result.totalCount);
    } catch (reason) {
      setError(errorMessage(reason));
    } finally {
      setLoading(false);
    }
  }, [api, page, pageSize, status]);

  useEffect(() => { void load(); }, [load]);

  const archive = async (event: React.MouseEvent, model: Model) => {
    event.stopPropagation();
    if (!api || !window.confirm(`Archive "${model.name}"?`)) return;
    try {
      await api.archiveModel(model.id);
      await load();
    } catch (reason) {
      setError(errorMessage(reason));
    }
  };

  return (
    <div className="page">
      <div className="page-header"><h1>Models</h1><Link className="button primary" href="/models/new"><Plus size={18} /> New Model</Link></div>
      <div className="filter-bar" role="group" aria-label="Status filter">
        {statusOptions.map(option => {
          const active = option === 'All' ? status === undefined : status === option;
          return <button className={`chip ${active ? 'active' : ''}`} key={option} onClick={() => { setStatus(option === 'All' ? undefined : option); setPage(1); }}>{option}</button>;
        })}
      </div>
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading models" /> : models.length === 0 ? (
        <div className="empty-state"><p>No models found.</p><Link className="button primary" href="/models/new">Create your first model</Link></div>
      ) : (
        <section className="card">
          <div className="table-wrap"><table><thead><tr><th>Name</th><th>Status</th><th>Version</th><th>Created By</th><th>Updated</th><th /></tr></thead><tbody>
            {models.map(model => <tr className="clickable-row" key={model.id} onClick={() => router.push(`/models/${model.id}`)}><td>{model.name}</td><td><StatusBadge status={model.status} /></td><td>v{model.version}</td><td>{model.createdBy}</td><td>{formatDate(model.updatedAtUtc, 'short')}</td><td><button className="icon-button" aria-label={`Archive ${model.name}`} onClick={event => void archive(event, model)}><Archive size={18} /></button></td></tr>)}
          </tbody></table></div>
          <div className="pagination"><button className="button secondary" disabled={page === 1} onClick={() => setPage(value => value - 1)}>Previous</button><span>Page {page} of {Math.max(1, Math.ceil(total / pageSize))}</span><button className="button secondary" disabled={page * pageSize >= total} onClick={() => setPage(value => value + 1)}>Next</button></div>
        </section>
      )}
    </div>
  );
}
