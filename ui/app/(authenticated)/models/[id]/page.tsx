'use client';

import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, Edit3, Play } from 'lucide-react';
import { ErrorNotice } from '@/components/ErrorNotice';
import { Loading } from '@/components/Loading';
import { ModelSummary } from '@/components/models/ModelSummary';
import { RunsTable } from '@/components/runs/RunsTable';
import { Button, ButtonLink } from '@/components/ui/Button';
import { Card, CardBody, CardHeader } from '@/components/ui/Card';
import { Page, PageHeader } from '@/components/ui/Page';
import { errorMessage } from '@/lib/format';
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
    <Page>
      <PageHeader>
        <h1>{model.name}</h1>
        <div className="flex flex-wrap items-center gap-2">
          <ButtonLink variant="secondary" href="/models"><ArrowLeft size={17} /> Back</ButtonLink>
          <ButtonLink variant="secondary" href={`/models/${id}/edit`}><Edit3 size={17} /> Edit</ButtonLink>
          <Button disabled={model.status === 'Archived' || requesting} onClick={() => void requestRun()}><Play size={17} /> {requesting ? 'Requesting…' : 'Run Model'}</Button>
        </div>
      </PageHeader>
      {error && <ErrorNotice message={error} />}
      <ModelSummary model={model} />
      {model.parameters && (
        <Card className="mb-[18px]">
          <CardHeader><h2>Parameters</h2></CardHeader>
          <CardBody>
            <pre className="m-0 overflow-auto rounded-[9px] bg-surface-muted p-[15px] text-xs text-foreground">{JSON.stringify(model.parameters, null, 2)}</pre>
          </CardBody>
        </Card>
      )}
      <Card>
        <CardHeader>
          <h2>Recent Runs</h2>
          <span className="flex-1" />
          <ButtonLink variant="ghost" href={`/models/${id}/runs`}>View All</ButtonLink>
        </CardHeader>
        {runs.length === 0 ? (
          <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted"><p>No runs yet.</p></div>
        ) : (
          <RunsTable runs={runs} variant="recent" onOpen={run => router.push(`/models/${id}/runs/${run.id}`)} />
        )}
      </Card>
    </Page>
  );
}
