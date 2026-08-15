/** Persisted browser key for the user's color-theme preference. */
export const THEME_STORAGE_KEY = 'ea:theme';

/** Dark color-theme identifier used by CSS and browser storage. */
export const DARK_THEME = 'dark';

/** Light color-theme identifier used by CSS and browser storage. */
export const LIGHT_THEME = 'light';

/** Supported application color theme. */
export type Theme = typeof DARK_THEME | typeof LIGHT_THEME;

/** Resolves a stored theme, falling back to the operating-system preference. */
export function resolveTheme(storedTheme: string | null, prefersDark: boolean): Theme {
  if (storedTheme === DARK_THEME || storedTheme === LIGHT_THEME) return storedTheme;
  return prefersDark ? DARK_THEME : LIGHT_THEME;
}

/** Applies the selected theme to the document root. */
export function applyTheme(theme: Theme): void {
  document.documentElement.dataset.theme = theme;
}
