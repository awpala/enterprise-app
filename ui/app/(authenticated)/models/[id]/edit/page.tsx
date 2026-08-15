import { ModelForm } from '@/components/ModelForm';

/** Renders the model edit route for the dynamic model identifier. */
export default async function EditModelPage({ params }: { readonly params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <ModelForm modelId={id} />;
}
