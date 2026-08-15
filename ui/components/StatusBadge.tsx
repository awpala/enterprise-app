import { cx } from '@/utils/classNames';

const STATUS_STYLES: Readonly<Record<string, string>> = {
  active: 'bg-success/15 text-success',
  archived: 'bg-danger/15 text-danger',
  completed: 'bg-success/15 text-success',
  draft: 'bg-warning/15 text-warning',
  failed: 'bg-danger/15 text-danger',
  pending: 'bg-warning/15 text-warning',
  running: 'bg-primary-soft text-primary',
};

export function StatusBadge({ status }: { readonly status: string }) {
  return (
    <span className={cx(
      'inline-flex rounded-full px-[9px] py-1 text-[11px] font-extrabold',
      STATUS_STYLES[status.toLowerCase()] ?? 'bg-surface-muted text-muted',
    )}>
      {status}
    </span>
  );
}
