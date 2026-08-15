'use client';

import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, Play } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Loading } from '@/components/Loading';
import { RunsTable } from '@/components/runs/RunsTable';
import { Button, ButtonLink } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { Page, PageHeader } from '@/components/ui/Page';
import { errorMessage } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelRun } from '@/lib/types';

/** Renders the complete run history for one model. */
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

  return (
    <Page fillAvailableHeight>
      <PageHeader>
        <h1>Model Runs</h1>
        <div className="flex flex-wrap items-center gap-2">
          <ButtonLink variant="secondary" href={`/models/${id}`}><ArrowLeft size={17} /> Back to Model</ButtonLink>
          <Button disabled={requesting} onClick={() => void request()}><Play size={17} /> New Run</Button>
        </div>
      </PageHeader>
      {error && <ErrorNotice message={error} />}
      {loading ? <Loading label="Loading runs" /> : runs.length === 0 ? (
        <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted"><p>No runs yet.</p></div>
      ) : (
        <Card className="flex min-h-0 shrink flex-col"><RunsTable runs={runs} variant="model" onOpen={run => router.push(`/models/${id}/runs/${run.id}`)} /></Card>
      )}
    </Page>
  );
}
