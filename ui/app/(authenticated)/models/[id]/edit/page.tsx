import { ModelForm } from '@/components/ModelForm';

export default async function EditModelPage({ params }: { readonly params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ModelForm modelId={id} />;
}
