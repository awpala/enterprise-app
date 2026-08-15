import { AppShell } from '@/components/AppShell';

/** Wraps authenticated routes in the guarded application shell. */
export default function AuthenticatedLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AppShell>{children}</AppShell>;
}
