import Link from 'next/link';
import { LayoutDashboard, PlayCircle, TestTube2 } from 'lucide-react';
import { cx } from '@/utils/classNames';

const navigation = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/models', label: 'Models', icon: TestTube2 },
  { href: '/runs', label: 'Runs', icon: PlayCircle },
] as const;

/** Primary application navigation. */
export function ApplicationNavigation({ pathname }: { readonly pathname: string }) {
  return (
    <aside className="fixed top-16 z-15 h-[calc(100vh-4rem)] w-[230px] border-r border-border bg-surface px-3 py-[18px] shadow-elevated sm:sticky sm:shadow-none">
      <nav className="grid gap-[5px]">
        {navigation.map(item => {
          const Icon = item.icon;
          const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
          return (
            <Link
              className={cx(
                'flex items-center gap-3 rounded-[10px] px-[13px] py-[11px] font-semibold transition-colors',
                active
                  ? 'bg-primary-soft text-primary'
                  : 'text-muted hover:bg-surface-muted hover:text-foreground',
              )}
              href={item.href}
              key={item.href}
            >
              <Icon size={19} /> {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
