import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

import { UiStateService, UI_STATE_KEYS } from './ui-state.service';

describe('UiStateService', () => {
  let service: UiStateService;

  beforeEach(() => {
    localStorage.clear();
    TestBed.configureTestingModule({ providers: [UiStateService] });
    service = TestBed.inject(UiStateService);
  });

  afterEach(() => {
    localStorage.clear();
    vi.restoreAllMocks();
  });

  describe('UI_STATE_KEYS', () => {
    it('exposes the documented namespaced keys', () => {
      expect(UI_STATE_KEYS.sidenavOpen).toBe('ea:ui:sidenav:open');
      expect(UI_STATE_KEYS.modelFormDraft).toBe('ea:ui:model-form:draft');
      expect(UI_STATE_KEYS.modelFormDraftEdit('abc')).toBe('ea:ui:model-form:draft:abc');
    });
  });

  describe('set/get round trip', () => {
    it('round-trips a string value', () => {
      service.set('k:string', 'hello');
      expect(service.get<string>('k:string', '')).toBe('hello');
    });

    it('round-trips a boolean value (including false)', () => {
      service.set('k:bool', false);
      expect(service.get<boolean>('k:bool', true)).toBe(false);
    });

    it('round-trips a number value (including 0)', () => {
      service.set('k:num', 0);
      expect(service.get<number>('k:num', 99)).toBe(0);
    });

    it('round-trips a nested object value', () => {
      const payload = { a: 1, b: { c: [1, 2, 3], d: 'x' } };
      service.set('k:obj', payload);
      expect(service.get('k:obj', null)).toEqual(payload);
    });
  });

  describe('get fallback behavior', () => {
    it('returns the provided default when key is missing', () => {
      expect(service.get<string>('missing-key', 'default-val')).toBe('default-val');
    });

    it('returns the default when stored JSON is corrupt (no throw)', () => {
      localStorage.setItem('k:corrupt', '{not-json');
      expect(() => service.get<unknown>('k:corrupt', 'fallback')).not.toThrow();
      expect(service.get<string>('k:corrupt', 'fallback')).toBe('fallback');
    });
  });

  describe('remove', () => {
    it('wipes a previously-stored key', () => {
      service.set('k:rm', { a: 1 });
      service.remove('k:rm');
      expect(service.get('k:rm', null)).toBeNull();
      expect(localStorage.getItem('k:rm')).toBeNull();
    });

    it('is a silent no-op when the key does not exist', () => {
      expect(() => service.remove('never-set')).not.toThrow();
    });
  });

  describe('error swallowing', () => {
    it('set does not throw when localStorage.setItem throws (quota)', () => {
      const spy = vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
        throw new DOMException('QuotaExceededError', 'QuotaExceededError');
      });
      expect(() => service.set('k:quota', { big: 'payload' })).not.toThrow();
      expect(spy).toHaveBeenCalled();
    });

    it('remove does not throw when localStorage.removeItem throws', () => {
      vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
        throw new Error('boom');
      });
      expect(() => service.remove('k:x')).not.toThrow();
    });

    it('get does not throw when localStorage.getItem throws', () => {
      vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
        throw new Error('boom');
      });
      expect(() => service.get('k:x', 'fb')).not.toThrow();
      expect(service.get('k:x', 'fb')).toBe('fb');
    });
  });

  describe('signalFor', () => {
    it('seeds the signal from the fallback when nothing is stored', () => {
      const sig = service.signalFor<boolean>('k:sig-seed', true);
      expect(sig()).toBe(true);
    });

    it('seeds the signal from the stored value when one exists', () => {
      service.set('k:sig-pre', 42);
      const sig = service.signalFor<number>('k:sig-pre', 0);
      expect(sig()).toBe(42);
    });

    it('.set() writes back to storage', () => {
      const sig = service.signalFor<string>('k:sig-write', 'init');
      sig.set('changed');
      expect(sig()).toBe('changed');
      expect(service.get<string>('k:sig-write', '')).toBe('changed');
    });

    it('.update() writes back to storage', () => {
      const sig = service.signalFor<number>('k:sig-upd', 1);
      sig.update(v => v + 10);
      expect(sig()).toBe(11);
      expect(service.get<number>('k:sig-upd', 0)).toBe(11);
    });
  });

  // SSR-safety note: the service guards on `typeof localStorage !== 'undefined'`
  // at construction time. Exercising the `storage === null` branch from Vitest's
  // jsdom environment would require re-importing the module with `localStorage`
  // stubbed out of globalThis — more machinery than it's worth for a single
  // one-line guard. The error-swallowing tests above cover the runtime failure
  // modes that matter in practice (quota, access errors).
});
