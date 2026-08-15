import type { HTMLAttributes } from 'react';
import { cx } from '@/utils/classNames';

interface PageProps extends HTMLAttributes<HTMLDivElement> {
  readonly fillAvailableHeight?: boolean;
}

/** Standard constrained application page. */
export function Page({ className, fillAvailableHeight = false, ...props }: PageProps) {
  return <div className={cx('mx-auto w-full max-w-[1180px] pb-8', fillAvailableHeight && 'flex h-full min-h-0 flex-col', className)} {...props} />;
}

/** Standard responsive title and actions row. */
export function PageHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cx('mb-[22px] flex flex-col items-start justify-between gap-[18px] sm:flex-row sm:items-center [&_h1]:m-0 [&_h1]:text-[28px] [&_h1]:font-bold [&_h1]:tracking-[-0.03em]', className)} {...props} />;
}
