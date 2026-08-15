'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Activity, TestTube2 } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Loading } from '@/components/Loading';
import { ButtonLink } from '@/components/ui/Button';
import { Card, CardHeader } from '@/components/ui/Card';
import { DataTable } from '@/components/ui/DataTable';
import { Page, PageHeader } from '@/components/ui/Page';
import { useApi } from '@/lib/use-api';
import { errorMessage } from '@/lib/format';
import type { Model } from '@/lib/types';
import { createModelTableColumns } from '@/utils/modelTableColumns';

const modelColumns = createModelTableColumns({ compact: true });

/** Renders aggregate model/run totals and recent model activity. */
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
    <Page fillAvailableHeight>
      <PageHeader><h1>Dashboard</h1></PageHeader>
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading dashboard" /> : (
        <>
          <div className="mb-[18px] grid auto-rows-fr grid-cols-1 items-stretch gap-4 sm:grid-cols-2">
            <Card className="flex h-full items-center gap-4 p-[22px]">
              <span className="grid size-12 place-items-center rounded-[14px] bg-primary-soft text-primary"><TestTube2 /></span>
              <div className="flex flex-col">
                <span className="text-3xl leading-none font-extrabold">{total}</span>
                <span className="text-[13px] text-muted">Total Models</span>
              </div>
            </Card>
            <Card className="flex h-full items-center gap-4 p-[22px]">
              <span className="grid size-12 place-items-center rounded-[14px] bg-primary-soft text-primary"><Activity /></span>
              <div className="flex flex-col">
                <span className="text-3xl leading-none font-extrabold">{active}</span>
                <span className="text-[13px] text-muted">Active Models</span>
              </div>
            </Card>
          </div>
          <Card className="flex min-h-0 shrink flex-col">
            <CardHeader>
              <h2>Recent Models</h2>
              <span className="flex-1" />
              <ButtonLink variant="ghost" href="/models">View All</ButtonLink>
            </CardHeader>
            {models.length === 0 ? (
              <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted">
                <p>No models yet.</p>
                <ButtonLink href="/models/new">Create Model</ButtonLink>
              </div>
            ) : (
              <DataTable
                ariaLabel="Recent models"
                bottomSpacing={false}
                columns={modelColumns}
                onRowActivate={model => router.push(`/models/${model.id}`)}
                rowKey={model => model.id}
                rows={models}
              />
            )}
          </Card>
        </>
      )}
    </Page>
  );
}
