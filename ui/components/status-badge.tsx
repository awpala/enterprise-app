export function StatusBadge({ status }: { readonly status: string }) {
  return <span className={`status status-${status.toLowerCase()}`}>{status}</span>;
}
