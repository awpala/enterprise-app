import type { ReactNode } from 'react';

interface PageTitleProps {
  readonly children: ReactNode;
  readonly subtitle?: ReactNode;
}

/** Standard page title with an optional supporting subtitle. */
export function PageTitle({ children, subtitle }: PageTitleProps) {
  return (
    <div>
      <h1>{children}</h1>
      {subtitle && <p className="mt-1 text-sm text-muted">{subtitle}</p>}
    </div>
  );
}
