import { Spinner } from './Spinner';

/** Standard centered loading state. */
export function Loading({ label = 'Loading' }: { readonly label?: string }) {
  return (
    <div className="flex min-h-[180px] flex-col items-center justify-center gap-3 text-muted">
      <Spinner />
      <span>{label}</span>
    </div>
  );
}
