import { cx } from '@/utils/classNames';

interface StatusFilterProps<T extends string> {
  readonly active: T;
  readonly label?: string;
  readonly onChange: (value: T) => void;
  readonly options: readonly T[];
}

/** Standard compact filter for status-like values. */
export function StatusFilter<T extends string>({ active, label = 'Status filter', onChange, options }: StatusFilterProps<T>) {
  return (
    <div className="mb-4 flex flex-wrap gap-2" role="group" aria-label={label}>
      {options.map(option => (
        <button
          className={cx(
            'cursor-pointer rounded-full border px-3 py-[7px] font-bold transition-colors',
            active === option
              ? 'border-primary/30 bg-primary-soft text-primary'
              : 'border-border bg-surface text-muted hover:bg-surface-muted hover:text-foreground',
          )}
          key={option}
          onClick={() => onChange(option)}
          type="button"
        >
          {option}
        </button>
      ))}
    </div>
  );
}
