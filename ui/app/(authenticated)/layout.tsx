import { AppShell } from '@/components/AppShell';

export default function AuthenticatedLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <AppShell>{children}</AppShell>;
}
