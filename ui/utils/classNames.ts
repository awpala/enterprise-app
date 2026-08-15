/** Joins conditional Tailwind class names without adding a runtime dependency. */
export function cx(...classes: ReadonlyArray<string | false | null | undefined>): string {
  return classes.filter(Boolean).join(' ');
}
