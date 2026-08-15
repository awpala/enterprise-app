'use client';

import { useEffect, useMemo, useState, type SubmitEvent } from 'react';
import { useRouter } from 'next/navigation';
import { errorMessage } from '@/lib/format';
import { useApi } from '@/lib/use-api';
import type { ModelFormState } from '@/components/models/ModelFields';

const EMPTY_FORM: ModelFormState = {
  name: '', description: '', status: 'Draft', distribution: '', mean: '', stdDev: '', sampleSize: '',
};

/** Owns model-form loading, validation, draft persistence, and submission. */
export function useModelForm(modelId?: string) {
  const api = useApi();
  const router = useRouter();
  const [form, setForm] = useState<ModelFormState>(EMPTY_FORM);
  const [baseline, setBaseline] = useState<ModelFormState>(EMPTY_FORM);
  const [loading, setLoading] = useState(Boolean(modelId));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const draftKey = `ea:model-form:${modelId ?? 'new'}`;

  useEffect(() => {
    if (!api) return;
    if (!modelId) {
      const draft = localStorage.getItem(draftKey);
      if (draft) setForm(JSON.parse(draft) as ModelFormState);
      return;
    }
    void api.getModel(modelId)
      .then(model => {
        const value: ModelFormState = {
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
        setForm(draft ? JSON.parse(draft) as ModelFormState : value);
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

  const update = (field: keyof ModelFormState, value: string) => setForm(current => ({ ...current, [field]: value }));
  const clear = () => setForm(EMPTY_FORM);
  const cancel = () => {
    localStorage.removeItem(draftKey);
    router.push(modelId ? `/models/${modelId}` : '/models');
  };

  const submit = async (event: SubmitEvent<HTMLFormElement>) => {
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

  return { cancel, clear, error, form, loading, saving, submit, update, valid } as const;
}
