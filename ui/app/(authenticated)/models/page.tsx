'use client';

import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Loading } from '@/components/Loading';
import { ButtonLink } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { DataTable } from '@/components/ui/DataTable';
import { Page, PageHeader } from '@/components/ui/Page';
import { PageTitle } from '@/components/ui/PageTitle';
import { Pagination } from '@/components/ui/Pagination';
import { StatusFilter } from '@/components/ui/StatusFilter';
import { errorMessage } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { Model, ModelStatus } from '@/lib/types';
import { createModelTableColumns } from '@/utils/modelTableColumns';

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

  const archive = async (model: Model) => {
    if (!api || !window.confirm(`Archive "${model.name}"?`)) return;
    try {
      await api.archiveModel(model.id);
      await load();
    } catch (reason) {
      setError(errorMessage(reason));
    }
  };

  return (
    <Page fillAvailableHeight>
      <PageHeader>
        <PageTitle subtitle={`${total.toLocaleString()} total ${total === 1 ? 'model' : 'models'}`}>Models</PageTitle>
        <ButtonLink href="/models/new"><Plus size={18} /> New Model</ButtonLink>
      </PageHeader>
      <StatusFilter
        active={status ?? 'All'}
        onChange={option => {
          setStatus(current => option === 'All' || option === current ? undefined : option);
          setPage(1);
        }}
        options={statusOptions}
      />
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading models" /> : models.length === 0 ? (
        <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted">
          <p>No models found.</p>
          <ButtonLink href="/models/new">Create your first model</ButtonLink>
        </div>
      ) : (
        <Card className="flex min-h-0 shrink flex-col">
          <DataTable
            ariaLabel="Models"
            columns={createModelTableColumns({ onArchive: model => void archive(model) })}
            onRowActivate={model => router.push(`/models/${model.id}`)}
            rowKey={model => model.id}
            rows={models}
          />
          <Pagination itemLabel="Model" onNext={() => setPage(value => value + 1)} onPrevious={() => setPage(value => value - 1)} page={page} pageSize={pageSize} total={total} />
        </Card>
      )}
    </Page>
  );
}
