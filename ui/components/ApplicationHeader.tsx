import Link from 'next/link';
import { Github, LogOut, Menu, Moon, Sun } from 'lucide-react';
import { DARK_THEME } from '@/lib/theme';
import { IconButton, IconLink } from './ui/Button';

interface ApplicationHeaderProps {
  readonly accountName?: string;
  readonly deploymentTarget?: string;
  readonly identityProvider?: string;
  readonly menuOpen: boolean;
  readonly onLogout: () => void;
  readonly onMenuToggle: () => void;
  readonly onThemeToggle: () => void;
  readonly theme: string;
}

/** Global application header and primary actions. */
export function ApplicationHeader({
  accountName,
  deploymentTarget,
  identityProvider,
  menuOpen,
  onLogout,
  onMenuToggle,
  onThemeToggle,
  theme,
}: ApplicationHeaderProps) {
  return (
    <header className="sticky top-0 z-20 flex h-16 items-center gap-[10px] bg-[#263f9c] px-[18px] text-white shadow-[0_2px_12px_rgb(0_0_0/18%)]">
      <IconButton variant="header" onClick={onMenuToggle} aria-expanded={menuOpen} aria-label="Toggle navigation">
        <Menu />
      </IconButton>
      <Link href="/dashboard" className="text-lg font-[760] tracking-[-0.02em]">Enterprise App</Link>
      <span className="flex-1" />
      <span className="hidden rounded-full border border-white/30 px-[9px] py-[3px] text-[11px] uppercase sm:inline">
        {deploymentTarget}
      </span>
      <IconButton variant="header" onClick={onThemeToggle} aria-label="Toggle theme">
        {theme === DARK_THEME ? <Sun /> : <Moon />}
      </IconButton>
      <IconLink variant="header" href="https://github.com/awpala/enterprise-app" target="_blank" rel="noreferrer" aria-label="View source">
        <Github />
      </IconLink>
      <div className="mx-1 hidden flex-col leading-[1.1] sm:flex">
        <strong className="text-[13px]">{accountName}</strong>
        <small className="text-[10px] text-white/70">{identityProvider}</small>
      </div>
      <IconButton variant="header" onClick={onLogout} aria-label="Sign out"><LogOut /></IconButton>
    </header>
  );
}
