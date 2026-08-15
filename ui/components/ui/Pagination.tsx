import { Button } from './Button';

interface PaginationProps {
  readonly itemLabel: string;
  readonly onNext: () => void;
  readonly onPrevious: () => void;
  readonly page: number;
  readonly pageSize: number;
  readonly total: number;
}

/** Standard previous/next pagination control. */
export function Pagination({ itemLabel, onNext, onPrevious, page, pageSize, total }: PaginationProps) {
  const pageCount = Math.max(1, Math.ceil(total / pageSize));
  return (
    <nav className="flex flex-wrap items-center justify-end gap-[10px] border-t border-border px-4 py-[14px]" aria-label={`${itemLabel} pages`}>
      <Button variant="secondary" disabled={page === 1} onClick={onPrevious}>Previous</Button>
      <span className="text-[13px] text-muted">Page {page} of {pageCount}</span>
      <Button variant="secondary" disabled={page >= pageCount} onClick={onNext}>Next</Button>
    </nav>
  );
}
