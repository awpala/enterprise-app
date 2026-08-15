import Link from 'next/link';
import type { ComponentPropsWithoutRef, ReactNode } from 'react';
import { cx } from '@/utils/classNames';

type ButtonVariant = 'danger' | 'ghost' | 'primary' | 'secondary';
type IconButtonVariant = 'header' | 'surface';

const BASE = 'inline-flex min-h-10 cursor-pointer items-center justify-center gap-2 rounded-[10px] border px-[15px] py-2 font-bold transition-colors focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-primary/20 disabled:cursor-not-allowed disabled:opacity-50';
const VARIANTS: Readonly<Record<ButtonVariant, string>> = {
  danger: 'border-danger/40 bg-transparent text-danger hover:bg-danger/10',
  ghost: 'border-transparent bg-transparent text-primary hover:bg-primary-soft',
  primary: 'border-transparent bg-primary text-white hover:bg-primary-hover',
  secondary: 'border-border bg-surface text-foreground hover:bg-surface-muted',
};
const ICON_BASE = 'inline-grid size-10 shrink-0 cursor-pointer place-items-center rounded-[10px] border-0 bg-transparent p-0 transition-colors focus-visible:outline-none focus-visible:ring-3 focus-visible:ring-primary/20 [&_svg]:size-5';
const ICON_VARIANTS: Readonly<Record<IconButtonVariant, string>> = {
  header: 'text-inherit hover:bg-white/12',
  surface: 'text-muted hover:bg-surface-muted hover:text-foreground',
};

interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  readonly variant?: ButtonVariant;
}

/** Standard application button. */
export function Button({ className, variant = 'primary', type = 'button', ...props }: ButtonProps) {
  return <button className={cx(BASE, VARIANTS[variant], className)} type={type} {...props} />;
}

interface ButtonLinkProps {
  readonly children: ReactNode;
  readonly className?: string;
  readonly href: string;
  readonly variant?: ButtonVariant;
}

/** Link rendered with the standard application button treatment. */
export function ButtonLink({ children, className, href, variant = 'primary' }: ButtonLinkProps) {
  return <Link className={cx(BASE, VARIANTS[variant], className)} href={href}>{children}</Link>;
}

interface IconButtonProps extends ComponentPropsWithoutRef<'button'> {
  readonly variant?: IconButtonVariant;
}

/** Standard icon-only action button. */
export function IconButton({ className, type = 'button', variant = 'surface', ...props }: IconButtonProps) {
  return <button className={cx(ICON_BASE, ICON_VARIANTS[variant], className)} type={type} {...props} />;
}

interface IconLinkProps extends ComponentPropsWithoutRef<'a'> {
  readonly href: string;
  readonly variant?: IconButtonVariant;
}

/** Standard icon-only external link. */
export function IconLink({ className, variant = 'surface', ...props }: IconLinkProps) {
  return <a className={cx(ICON_BASE, ICON_VARIANTS[variant], className)} {...props} />;
}
