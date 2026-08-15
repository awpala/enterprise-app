import type { Metadata } from 'next';
import { AuthProvider } from '@/components/AuthProvider';
import { ThemeProvider } from '@/components/ThemeProvider';
import './globals.css';

export const metadata: Metadata = {
  title: 'Enterprise App',
  description: 'Model-driven workflows and asynchronous job processing.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html className="min-h-full" lang="en" suppressHydrationWarning>
      <body className="min-h-screen bg-background font-sans text-foreground antialiased">
        <ThemeProvider>
          <AuthProvider>{children}</AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
