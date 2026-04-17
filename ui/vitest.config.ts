/// <reference types="vitest" />
import { defineConfig } from 'vite';
import angular from '@analogjs/vite-plugin-angular';

export default defineConfig({
  plugins: [angular()],
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['src/**/*.spec.ts'],
    setupFiles: ['src/test-setup.ts'],
    // jsdom's CSSOM can't parse modern CSS features (e.g. `@layer`) used by
    // Angular CDK/Material and emits noisy parse errors to stderr. These are
    // harmless in tests (jsdom never actually renders styles), so filter them.
    onConsoleLog(log) {
      if (log.includes('Could not parse CSS stylesheet')) return false;
    },
  },
});
