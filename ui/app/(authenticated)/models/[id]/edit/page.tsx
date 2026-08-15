import { ModelForm } from '@/components/model-form';

export default async function EditModelPage({ params }: { readonly params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ModelForm modelId={id} />;
}
