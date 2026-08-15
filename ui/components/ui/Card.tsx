import type { HTMLAttributes } from 'react';
import { cx } from '@/utils/classNames';

/** Standard bordered content surface. */
export function Card({ className, ...props }: HTMLAttributes<HTMLElement>) {
  return <section className={cx('overflow-hidden rounded-[14px] border border-border bg-surface shadow-card', className)} {...props} />;
}

/** Standard heading row within a card. */
export function CardHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cx('flex items-center gap-3 border-b border-border px-5 py-[18px] [&_h2]:m-0 [&_h2]:text-[17px] [&_h2]:font-bold', className)} {...props} />;
}

/** Standard padded card content. */
export function CardBody({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cx('p-5', className)} {...props} />;
}
