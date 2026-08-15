import { describe, expect, it } from 'vitest';
import { DARK_THEME, LIGHT_THEME, resolveTheme } from './theme';

describe('resolveTheme', () => {
  it('preserves an explicit stored preference', () => {
    expect(resolveTheme(DARK_THEME, false)).toBe(DARK_THEME);
    expect(resolveTheme(LIGHT_THEME, true)).toBe(LIGHT_THEME);
  });

  it('falls back to the operating-system preference', () => {
    expect(resolveTheme(null, true)).toBe(DARK_THEME);
    expect(resolveTheme(null, false)).toBe(LIGHT_THEME);
  });
});
