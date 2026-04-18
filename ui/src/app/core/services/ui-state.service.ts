import { Injectable, signal, WritableSignal } from '@angular/core';

/**
 * Namespaced localStorage keys for UI state persistence.
 * Prefixed with `ea:ui:` to avoid collisions with other apps on the same origin
 * and to make keys easy to identify in browser devtools.
 */
export const UI_STATE_KEYS = {
  sidenavOpen: 'ea:ui:sidenav:open',
  modelFormDraft: 'ea:ui:model-form:draft',
  modelFormDraftEdit: (id: string) => `ea:ui:model-form:draft:${id}`,
  theme: 'ea:ui:theme',
  modelsTableFilter: 'ea:ui:models-table:filter',
  modelsTablePageSize: 'ea:ui:models-table:page-size',
  runsTableFilter: 'ea:ui:runs-table:filter',
  runsTablePageSize: 'ea:ui:runs-table:page-size',
} as const;

/**
 * Mediates reads/writes of UI state to `localStorage` with typed accessors,
 * JSON serialization, and error swallowing on quota/parse failures.
 *
 * Use {@link signalFor} to get a `WritableSignal<T>` that reads its initial
 * value from storage and writes every update back. Use {@link get}/{@link set}
 * for one-shot operations.
 */
@Injectable({ providedIn: 'root' })
export class UiStateService {
  private readonly storage: Storage | null = typeof localStorage !== 'undefined' ? localStorage : null;

  /** Read and JSON-parse a value. Returns `fallback` on any error (missing, parse, access). */
  get<T>(key: string, fallback: T): T {
    if (!this.storage) return fallback;
    try {
      const raw = this.storage.getItem(key);
      if (raw === null) return fallback;
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  }

  /** JSON-serialize and write. Silently no-ops on quota or access errors. */
  set<T>(key: string, value: T): void {
    if (!this.storage) return;
    try {
      this.storage.setItem(key, JSON.stringify(value));
    } catch {
      // Quota exceeded, serialization error, or storage disabled — swallow.
    }
  }

  /** Remove a key. Silently no-ops on error. */
  remove(key: string): void {
    if (!this.storage) return;
    try {
      this.storage.removeItem(key);
    } catch {
      // Swallow.
    }
  }

  /**
   * Build a `WritableSignal<T>` seeded from persisted value, which writes back
   * to storage on every update. Intended for simple discrete UI flags.
   */
  signalFor<T>(key: string, fallback: T): WritableSignal<T> {
    const initial = this.get<T>(key, fallback);
    const sig = signal<T>(initial);
    const originalSet = sig.set.bind(sig);
    const originalUpdate = sig.update.bind(sig);
    sig.set = (value: T) => {
      originalSet(value);
      this.set(key, value);
    };
    sig.update = (updater: (current: T) => T) => {
      originalUpdate(updater);
      this.set(key, sig());
    };
    return sig;
  }
}
