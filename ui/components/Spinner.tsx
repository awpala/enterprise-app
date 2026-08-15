/** Shared animated progress indicator. */
export function Spinner({ label }: { readonly label?: string }) {
  return (
    <div
      className="size-[34px] animate-spin rounded-full border-3 border-border border-t-primary"
      aria-hidden={label ? undefined : true}
      aria-label={label}
      role={label ? 'status' : undefined}
    />
  );
}
