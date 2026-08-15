export function formatDate(value: string | null, style: 'short' | 'medium' = 'medium'): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: style,
    timeStyle: style === 'short' ? 'short' : 'medium',
  }).format(new Date(value));
}

export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'An unexpected error occurred.';
}
