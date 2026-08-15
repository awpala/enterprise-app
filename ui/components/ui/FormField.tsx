import type { ComponentPropsWithoutRef, ReactNode } from 'react';
import { cx } from '@/utils/classNames';

const CONTROL = 'w-full rounded-[9px] border border-border bg-surface px-3 py-[10px] text-foreground outline-none transition-shadow focus:border-primary focus:ring-3 focus:ring-primary/15';

interface FormFieldProps {
  readonly children: ReactNode;
  readonly hint?: string;
  readonly label: string;
  readonly name: string;
}

/** Standard labeled form-control container. */
export function FormField({ children, hint, label, name }: FormFieldProps) {
  return (
    <div className="grid gap-1.5">
      <label className="text-[13px] font-bold" htmlFor={name}>{label}</label>
      {children}
      {hint && <small className="text-muted">{hint}</small>}
    </div>
  );
}

/** Standard text or numeric input. */
export function Input({ className, ...props }: ComponentPropsWithoutRef<'input'>) {
  return <input className={cx(CONTROL, className)} {...props} />;
}

/** Standard select control. */
export function Select({ className, ...props }: ComponentPropsWithoutRef<'select'>) {
  return <select className={cx(CONTROL, className)} {...props} />;
}

/** Standard multiline input. */
export function Textarea({ className, ...props }: ComponentPropsWithoutRef<'textarea'>) {
  return <textarea className={cx(CONTROL, 'min-h-[100px] resize-y', className)} {...props} />;
}
