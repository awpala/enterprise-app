import type { KeyboardEvent, ReactNode } from 'react';
import { cx } from '@/utils/classNames';

/** Typed column definition for the shared data table. */
export interface DataTableColumn<T> {
  readonly cell: (item: T) => ReactNode;
  readonly cellClassName?: string;
  readonly header: ReactNode;
  readonly headerClassName?: string;
  readonly id: string;
}

interface DataTableProps<T> {
  readonly ariaLabel?: string;
  readonly bottomSpacing?: boolean;
  readonly columns: readonly DataTableColumn<T>[];
  readonly onRowActivate?: (item: T) => void;
  readonly rowKey: (item: T) => string;
  readonly rows: readonly T[];
}

/** Generic, responsive, keyboard-accessible application data table. */
export function DataTable<T>({ ariaLabel, bottomSpacing = true, columns, onRowActivate, rowKey, rows }: DataTableProps<T>) {
  const handleKeyDown = (event: KeyboardEvent<HTMLTableRowElement>, item: T) => {
    if (onRowActivate && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      onRowActivate(item);
    }
  };

  return (
    <div className={cx(
      'min-h-0 shrink overflow-auto [scrollbar-color:var(--border)_transparent] [scrollbar-width:thin] [&::-webkit-scrollbar]:size-2 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-border [&::-webkit-scrollbar-track]:bg-transparent',
      bottomSpacing && 'mb-4',
    )}>
      <table
        aria-label={ariaLabel}
        className="w-full border-collapse [&_td]:whitespace-nowrap [&_td]:border-b [&_td]:border-border [&_td]:px-4 [&_td]:py-[13px] [&_th]:whitespace-nowrap [&_th]:border-b [&_th]:border-border [&_th]:bg-surface-muted [&_th]:px-4 [&_th]:py-[13px] [&_th]:text-left [&_th]:text-xs [&_th]:font-extrabold [&_th]:tracking-[0.04em] [&_th]:text-muted [&_th]:uppercase [&_thead]:sticky [&_thead]:top-0 [&_thead]:z-10 [&_tbody_tr:last-child_td]:border-b-0"
      >
        <thead><tr>{columns.map(column => <th className={column.headerClassName} key={column.id}>{column.header}</th>)}</tr></thead>
        <tbody>
          {rows.map(item => (
            <tr
              className={cx(onRowActivate && 'cursor-pointer hover:[&_td]:bg-primary-soft/45 focus-visible:outline-none focus-visible:[&_td]:bg-primary-soft/45')}
              key={rowKey(item)}
              onClick={() => onRowActivate?.(item)}
              onKeyDown={event => handleKeyDown(event, item)}
              tabIndex={onRowActivate ? 0 : undefined}
            >
              {columns.map(column => <td className={column.cellClassName} key={column.id}>{column.cell(item)}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
