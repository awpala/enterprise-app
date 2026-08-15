'use client';

import { useCallback, useSyncExternalStore } from 'react';

/** Reactively reports whether the browser viewport matches a CSS media query. */
export function useMediaQuery(query: string): boolean {
  const subscribe = useCallback((onChange: () => void) => {
    if (typeof window === 'undefined' || !window.matchMedia) return () => undefined;
    const mediaQuery = window.matchMedia(query);
    mediaQuery.addEventListener('change', onChange);
    return () => mediaQuery.removeEventListener('change', onChange);
  }, [query]);

  const getSnapshot = useCallback(
    () => typeof window !== 'undefined' && Boolean(window.matchMedia?.(query).matches),
    [query],
  );

  return useSyncExternalStore(subscribe, getSnapshot, () => false);
}
