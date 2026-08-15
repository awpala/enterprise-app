'use client';

import {
  createContext,
  useCallback,
  useContext,
  useLayoutEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  applyTheme,
  DARK_THEME,
  LIGHT_THEME,
  resolveTheme,
  THEME_STORAGE_KEY,
  type Theme,
} from '../lib/theme';

interface ThemeContextValue {
  readonly theme: Theme;
  readonly toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

/** Provides the persisted browser theme to the application. */
export function ThemeProvider({ children }: { readonly children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>(LIGHT_THEME);

  useLayoutEffect(() => {
    const preferredTheme = resolveTheme(
      localStorage.getItem(THEME_STORAGE_KEY),
      window.matchMedia('(prefers-color-scheme: dark)').matches,
    );
    applyTheme(preferredTheme);
    setTheme(preferredTheme);
  }, []);

  const toggleTheme = useCallback(() => {
    setTheme(currentTheme => {
      const nextTheme = currentTheme === DARK_THEME ? LIGHT_THEME : DARK_THEME;
      localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
      applyTheme(nextTheme);
      return nextTheme;
    });
  }, []);

  const value = useMemo<ThemeContextValue>(() => ({ theme, toggleTheme }), [theme, toggleTheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

/** Returns the current browser theme and its toggle action. */
export function useTheme(): ThemeContextValue {
  const value = useContext(ThemeContext);
  if (!value) throw new Error('useTheme must be used inside ThemeProvider.');
  return value;
}
