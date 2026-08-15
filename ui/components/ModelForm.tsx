'use client';

import { ErrorNotice } from './ErrorNotice';
import { Loading } from './Loading';
import { ModelFields } from './models/ModelFields';
import { Button } from './ui/Button';
import { Card, CardBody } from './ui/Card';
import { Page, PageHeader } from './ui/Page';
import { useModelForm } from '@/hooks/useModelForm';

export function ModelForm({ modelId }: { readonly modelId?: string }) {
  const { cancel, clear, error, form, loading, saving, submit, update, valid } = useModelForm(modelId);

  if (loading) return <Loading label="Loading model" />;

  return (
    <Page>
      <PageHeader><h1>{modelId ? 'Edit Model' : 'New Model'}</h1></PageHeader>
      {error && <ErrorNotice message={error} />}
      <Card>
        <CardBody>
        <form className="grid gap-[17px]" onSubmit={event => void submit(event)}>
          <ModelFields editing={Boolean(modelId)} onChange={update} value={form} />
          <div className="flex justify-end gap-[10px] pt-[5px]">
            <Button variant="ghost" onClick={cancel}>Cancel</Button>
            <Button variant="secondary" onClick={clear}>Clear</Button>
            <Button type="submit" disabled={!valid || saving}>{saving ? 'Saving…' : modelId ? 'Update' : 'Create'}</Button>
          </div>
        </form>
        </CardBody>
      </Card>
    </Page>
  );
}
