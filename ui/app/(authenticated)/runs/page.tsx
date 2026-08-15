'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { RefreshCw } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Loading } from '@/components/Loading';
import { RunsTable } from '@/components/runs/RunsTable';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { Page, PageHeader } from '@/components/ui/Page';
import { PageTitle } from '@/components/ui/PageTitle';
import { Pagination } from '@/components/ui/Pagination';
import { StatusFilter } from '@/components/ui/StatusFilter';
import { errorMessage } from '@/lib/format';
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

  return (
    <Page fillAvailableHeight>
      <PageHeader>
        <PageTitle subtitle={`${total.toLocaleString()} total ${total === 1 ? 'run' : 'runs'}`}>Runs</PageTitle>
        <Button variant="secondary" onClick={() => void load()}><RefreshCw size={17} /> Refresh</Button>
      </PageHeader>
      <StatusFilter
        active={status ?? 'All'}
        onChange={option => {
          setStatus(current => option === 'All' || option === current ? undefined : option);
          setPage(1);
        }}
        options={options}
      />
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading runs" /> : runs.length === 0 ? (
        <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted"><p>No runs found.</p></div>
      ) : (
        <Card className="flex min-h-0 shrink flex-col">
          <RunsTable runs={runs} variant="global" onOpen={run => router.push(`/models/${run.modelId}/runs/${run.id}`)} />
          <Pagination itemLabel="Run" onNext={() => setPage(value => value + 1)} onPrevious={() => setPage(value => value - 1)} page={page} pageSize={pageSize} total={total} />
        </Card>
      )}
    </Page>
  );
}
