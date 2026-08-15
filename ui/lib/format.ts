/** Formats an ISO timestamp for display, or returns an em dash when absent. */
export function formatDate(value: string | null, style: 'short' | 'medium' = 'medium'): string {
  if (!value) return '—';
  return new Intl.DateTimeFormat('en-US', {
    dateStyle: style,
    timeStyle: style === 'short' ? 'short' : 'medium',
  }).format(new Date(value));
}

/** Converts an unknown caught value into a user-facing error message. */
export function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'An unexpected error occurred.';
}
