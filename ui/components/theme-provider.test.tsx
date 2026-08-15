import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { DARK_THEME, LIGHT_THEME, THEME_STORAGE_KEY } from '../lib/theme';
import { ThemeProvider, useTheme } from './theme-provider';

function ThemeConsumer() {
  const { theme, toggleTheme } = useTheme();
  return <button onClick={toggleTheme}>{theme}</button>;
}

describe('ThemeProvider', () => {
  beforeEach(() => {
    localStorage.clear();
    delete document.documentElement.dataset.theme;
    vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: false }));
  });

  afterEach(() => vi.unstubAllGlobals());

  it('restores and persists the browser theme through local storage', () => {
    localStorage.setItem(THEME_STORAGE_KEY, DARK_THEME);

    render(
      <ThemeProvider>
        <ThemeConsumer />
      </ThemeProvider>,
    );

    expect(screen.getByRole('button')).toHaveTextContent(DARK_THEME);
    expect(document.documentElement.dataset.theme).toBe(DARK_THEME);

    fireEvent.click(screen.getByRole('button'));

    expect(screen.getByRole('button')).toHaveTextContent(LIGHT_THEME);
    expect(document.documentElement.dataset.theme).toBe(LIGHT_THEME);
    expect(localStorage.getItem(THEME_STORAGE_KEY)).toBe(LIGHT_THEME);
  });
});
