import Link from 'next/link';
import { LayoutDashboard, PlayCircle, TestTube2 } from 'lucide-react';
import { cx } from '@/utils/classNames';

const navigation = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/models', label: 'Models', icon: TestTube2 },
  { href: '/runs', label: 'Runs', icon: PlayCircle },
] as const;

interface ApplicationNavigationProps {
  readonly onNavigate: () => void;
  readonly pathname: string;
}

/** Primary application navigation. */
export function ApplicationNavigation({ onNavigate, pathname }: ApplicationNavigationProps) {
  return (
    <aside
      className="fixed bottom-0 left-0 top-16 z-30 w-[230px] shrink-0 overflow-y-auto overscroll-contain border-r border-border bg-surface px-3 py-[18px] shadow-elevated sm:relative sm:inset-auto sm:h-full sm:shadow-none"
      id="application-navigation"
    >
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
              onClick={onNavigate}
            >
              <Icon size={19} /> {item.label}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
