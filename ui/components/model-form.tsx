'use client';

import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { ErrorNotice, Loading } from './loading';
import { errorMessage } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelStatus } from '@/lib/types';

interface FormState {
  readonly name: string;
  readonly description: string;
  readonly status: ModelStatus;
  readonly distribution: string;
  readonly mean: string;
  readonly stdDev: string;
  readonly sampleSize: string;
}

const emptyForm: FormState = {
  name: '',
  description: '',
  status: 'Draft',
  distribution: '',
  mean: '',
  stdDev: '',
  sampleSize: '',
};

export function ModelForm({ modelId }: { readonly modelId?: string }) {
  const api = useApi();
  const router = useRouter();
  const [form, setForm] = useState<FormState>(emptyForm);
  const [baseline, setBaseline] = useState<FormState>(emptyForm);
  const [loading, setLoading] = useState(Boolean(modelId));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const draftKey = `ea:model-form:${modelId ?? 'new'}`;

  useEffect(() => {
    if (!api) return;
    if (!modelId) {
      const draft = localStorage.getItem(draftKey);
      if (draft) setForm(JSON.parse(draft) as FormState);
      return;
    }
    void api.getModel(modelId)
      .then(model => {
        const value: FormState = {
          name: model.name,
          description: model.description ?? '',
          status: model.status,
          distribution: String(model.parameters?.distribution ?? 'normal'),
          mean: String(model.parameters?.mean ?? 0),
          stdDev: String(model.parameters?.stdDev ?? 1),
          sampleSize: String(model.parameters?.sampleSize ?? 1000),
        };
        setBaseline(value);
        const draft = localStorage.getItem(draftKey);
        setForm(draft ? JSON.parse(draft) as FormState : value);
      })
      .catch(reason => setError(errorMessage(reason)))
      .finally(() => setLoading(false));
  }, [api, modelId, draftKey]);

  useEffect(() => {
    const timer = window.setTimeout(() => localStorage.setItem(draftKey, JSON.stringify(form)), 300);
    return () => window.clearTimeout(timer);
  }, [draftKey, form]);

  const valid = useMemo(() => form.name.trim().length > 0
    && form.name.length <= 200
    && form.description.length <= 2000
    && form.distribution.length > 0
    && Number.isFinite(Number(form.mean))
    && Number(form.stdDev) >= 0.0001
    && Number(form.sampleSize) >= 1
    && Number(form.sampleSize) <= 100000
    && JSON.stringify(form) !== JSON.stringify(baseline), [form, baseline]);

  const update = (field: keyof FormState, value: string) => setForm(current => ({ ...current, [field]: value }));

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!api || !valid) return;
    setSaving(true);
    setError('');
    const input = {
      name: form.name.trim(),
      description: form.description.trim() || null,
      status: form.status,
      parameters: {
        distribution: form.distribution,
        mean: Number(form.mean),
        stdDev: Number(form.stdDev),
        sampleSize: Number(form.sampleSize),
      },
    };
    try {
      const model = modelId ? await api.updateModel(modelId, input) : await api.createModel(input);
      localStorage.removeItem(draftKey);
      router.push(`/models/${model.id}`);
    } catch (reason) {
      setError(errorMessage(reason));
      setSaving(false);
    }
  };

  if (loading) return <Loading label="Loading model" />;

  return (
    <div className="page">
      <div className="page-header"><h1>{modelId ? 'Edit Model' : 'New Model'}</h1></div>
      {error && <ErrorNotice message={error} />}
      <section className="card"><div className="card-body">
        <form className="form-grid" onSubmit={event => void submit(event)}>
          <div className="field"><label htmlFor="name">Name</label><input id="name" className="input" maxLength={200} required value={form.name} onChange={event => update('name', event.target.value)} /></div>
          <div className="field"><label htmlFor="description">Description</label><textarea id="description" className="textarea" maxLength={2000} value={form.description} onChange={event => update('description', event.target.value)} /></div>
          {modelId && <div className="field"><label htmlFor="status">Status</label><select id="status" className="select" value={form.status} onChange={event => update('status', event.target.value)}><option>Draft</option><option>Active</option><option>Archived</option></select></div>}
          <div><h2>Parameters</h2><div className="parameter-grid">
            <div className="field"><label htmlFor="distribution">Distribution</label><select id="distribution" className="select" required value={form.distribution} onChange={event => update('distribution', event.target.value)}><option value="">Select</option><option value="normal">normal</option><option value="uniform">uniform</option><option value="exponential">exponential</option><option value="lognormal">lognormal</option></select></div>
            <div className="field"><label htmlFor="mean">Mean</label><input id="mean" className="input" type="number" step="any" required value={form.mean} onChange={event => update('mean', event.target.value)} /></div>
            <div className="field"><label htmlFor="stdDev">Std Dev</label><input id="stdDev" className="input" type="number" step="any" min="0.0001" required value={form.stdDev} onChange={event => update('stdDev', event.target.value)} /></div>
            <div className="field"><label htmlFor="sampleSize">Sample Size</label><input id="sampleSize" className="input" type="number" min="1" max="100000" required value={form.sampleSize} onChange={event => update('sampleSize', event.target.value)} /></div>
          </div></div>
          <div className="form-actions">
            <button className="button ghost" type="button" onClick={() => { localStorage.removeItem(draftKey); router.push(modelId ? `/models/${modelId}` : '/models'); }}>Cancel</button>
            <button className="button secondary" type="button" onClick={() => setForm(emptyForm)}>Clear</button>
            <button className="button primary" type="submit" disabled={!valid || saving}>{saving ? 'Saving…' : modelId ? 'Update' : 'Create'}</button>
          </div>
        </form>
      </div></section>
    </div>
  );
}
