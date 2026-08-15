'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Activity, TestTube2 } from 'lucide-react';
import { ErrorNotice, Loading } from '@/components/loading';
import { StatusBadge } from '@/components/status-badge';
import { useApi } from '@/lib/use-api';
import { errorMessage, formatDate } from '@/lib/format';
import type { Model } from '@/lib/types';

export default function DashboardPage() {
  const api = useApi();
  const router = useRouter();
  const [models, setModels] = useState<Model[]>([]);
  const [total, setTotal] = useState(0);
  const [active, setActive] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!api) return;
    setLoading(true);
    void Promise.all([api.getModels(1, 5), api.getModels(1, 1, 'Active')])
      .then(([recent, activeModels]) => {
        setModels(recent.items);
        setTotal(recent.totalCount);
        setActive(activeModels.totalCount);
      })
      .catch(reason => setError(errorMessage(reason)))
      .finally(() => setLoading(false));
  }, [api]);

  return (
    <div className="page">
      <div className="page-header"><h1>Dashboard</h1></div>
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading dashboard" /> : (
        <>
          <div className="stat-grid">
            <div className="card stat-card"><span className="stat-icon"><TestTube2 /></span><div><span className="stat-value">{total}</span><span className="stat-label">Total Models</span></div></div>
            <div className="card stat-card"><span className="stat-icon"><Activity /></span><div><span className="stat-value">{active}</span><span className="stat-label">Active Models</span></div></div>
          </div>
          <section className="card">
            <div className="card-header"><h2>Recent Models</h2><span className="spacer" /><Link className="button ghost" href="/models">View All</Link></div>
            {models.length === 0 ? (
              <div className="empty-state"><p>No models yet.</p><Link className="button primary" href="/models/new">Create Model</Link></div>
            ) : (
              <div className="table-wrap"><table><thead><tr><th>Name</th><th>Status</th><th>Version</th><th>Updated</th></tr></thead><tbody>
                {models.map(model => <tr className="clickable-row" key={model.id} onClick={() => router.push(`/models/${model.id}`)}><td>{model.name}</td><td><StatusBadge status={model.status} /></td><td>v{model.version}</td><td>{formatDate(model.updatedAtUtc, 'short')}</td></tr>)}
              </tbody></table></div>
            )}
          </section>
        </>
      )}
    </div>
  );
}
