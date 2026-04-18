import '@angular/compiler';
import '@analogjs/vitest-angular/setup-zone';

import {
  BrowserTestingModule,
  platformBrowserTesting,
} from '@angular/platform-browser/testing';
import { getTestBed } from '@angular/core/testing';

getTestBed().initTestEnvironment(
  BrowserTestingModule,
  platformBrowserTesting(),
);

// jsdom forwards CSS-parse errors (from modern features like `@layer` that its
// CSSOM can't parse — Angular CDK/Material ship these) through its internal
// VirtualConsole, which bypasses both `console.error` and vitest's
// `onConsoleLog` hook. Replace the jsdomError listener to filter them at the
// source; anything unrelated still surfaces.
interface VirtualConsoleLike {
  removeAllListeners(event: string): void;
  on(event: string, listener: (error: Error) => void): void;
}
const virtualConsole =
  (globalThis as { _virtualConsole?: VirtualConsoleLike })._virtualConsole ??
  (typeof window !== 'undefined'
    ? (window as unknown as { _virtualConsole?: VirtualConsoleLike })._virtualConsole
    : undefined);
if (virtualConsole) {
  virtualConsole.removeAllListeners('jsdomError');
  virtualConsole.on('jsdomError', (error: Error) => {
    if (error.message === 'Could not parse CSS stylesheet') return;
    console.error(error);
  });
}
