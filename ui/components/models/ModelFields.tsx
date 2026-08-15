import type { ModelStatus } from '@/lib/types';
import { FormField, Input, Select, Textarea } from '../ui/FormField';

/** Editable values used by the model form. */
export interface ModelFormState {
  readonly name: string;
  readonly description: string;
  readonly status: ModelStatus;
  readonly distribution: string;
  readonly mean: string;
  readonly stdDev: string;
  readonly sampleSize: string;
}

interface ModelFieldsProps {
  readonly editing: boolean;
  readonly onChange: (field: keyof ModelFormState, value: string) => void;
  readonly value: ModelFormState;
}

/** Standard model identity and parameter form fields. */
export function ModelFields({ editing, onChange, value }: ModelFieldsProps) {
  return (
    <>
      <FormField label="Name" name="name">
        <Input id="name" maxLength={200} required value={value.name} onChange={event => onChange('name', event.target.value)} />
      </FormField>
      <FormField label="Description" name="description">
        <Textarea id="description" maxLength={2000} value={value.description} onChange={event => onChange('description', event.target.value)} />
      </FormField>
      {editing && (
        <FormField label="Status" name="status">
          <Select id="status" value={value.status} onChange={event => onChange('status', event.target.value)}>
            <option>Draft</option><option>Active</option><option>Archived</option>
          </Select>
        </FormField>
      )}
      <div>
        <h2 className="mb-3 text-xl font-bold">Parameters</h2>
        <div className="grid grid-cols-1 gap-[14px] sm:grid-cols-3">
          <FormField label="Distribution" name="distribution">
            <Select id="distribution" required value={value.distribution} onChange={event => onChange('distribution', event.target.value)}>
              <option value="">Select</option><option value="normal">normal</option><option value="uniform">uniform</option><option value="exponential">exponential</option><option value="lognormal">lognormal</option>
            </Select>
          </FormField>
          <FormField label="Mean" name="mean">
            <Input id="mean" type="number" step="any" required value={value.mean} onChange={event => onChange('mean', event.target.value)} />
          </FormField>
          <FormField label="Std Dev" name="stdDev">
            <Input id="stdDev" type="number" step="any" min="0.0001" required value={value.stdDev} onChange={event => onChange('stdDev', event.target.value)} />
          </FormField>
          <FormField label="Sample Size" name="sampleSize">
            <Input id="sampleSize" type="number" min="1" max="100000" required value={value.sampleSize} onChange={event => onChange('sampleSize', event.target.value)} />
          </FormField>
        </div>
      </div>
    </>
  );
}
