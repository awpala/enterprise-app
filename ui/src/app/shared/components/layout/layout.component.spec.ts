import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { provideNoopAnimations } from '@angular/platform-browser/animations';
import { BreakpointObserver } from '@angular/cdk/layout';
import { Subject } from 'rxjs';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

import { LayoutComponent } from './layout.component';
import { AuthService } from '../../../auth/auth.service';
import { UiStateService, UI_STATE_KEYS } from '../../../core/services/ui-state.service';

/**
 * Minimal fake AuthService — LayoutComponent injects it but the sidenav logic
 * under test never touches it. We supply the signals/methods the template uses
 * so change detection doesn't blow up.
 */
function createAuthServiceStub() {
  return {
    displayName: () => 'Test User',
    idp: () => 'test',
    logoutRedirect: vi.fn(),
  };
}

describe('LayoutComponent sidenav persistence', () => {
  let breakpointSubject: Subject<{ matches: boolean; breakpoints: Record<string, boolean> }>;
  let authStub: ReturnType<typeof createAuthServiceStub>;

  beforeEach(() => {
    localStorage.clear();
    breakpointSubject = new Subject();
    authStub = createAuthServiceStub();

    TestBed.configureTestingModule({
      imports: [LayoutComponent],
      providers: [
        provideNoopAnimations(),
        provideRouter([]),
        { provide: AuthService, useValue: authStub },
        {
          provide: BreakpointObserver,
          useValue: {
            observe: () => breakpointSubject.asObservable(),
            isMatched: () => false,
          },
        },
      ],
    });
  });

  afterEach(() => {
    localStorage.clear();
  });

  it('seeds sidenavOpen signal from the persisted value via UiStateService', () => {
    // Pre-seed storage with `false` — user had the sidenav collapsed.
    const ui = TestBed.inject(UiStateService);
    ui.set<boolean>(UI_STATE_KEYS.sidenavOpen, false);

    const fixture = TestBed.createComponent(LayoutComponent);
    const cmp = fixture.componentInstance;

    expect(cmp.sidenavOpen()).toBe(false);
  });

  it('defaults sidenavOpen to true when nothing is persisted', () => {
    const fixture = TestBed.createComponent(LayoutComponent);
    expect(fixture.componentInstance.sidenavOpen()).toBe(true);
  });

  it('onSidenavOpenedChange persists to storage on desktop', () => {
    const fixture = TestBed.createComponent(LayoutComponent);
    const cmp = fixture.componentInstance;
    // Emit desktop breakpoint result so isMobile() stays false.
    breakpointSubject.next({ matches: false, breakpoints: {} });

    cmp.onSidenavOpenedChange(false);

    expect(cmp.sidenavOpen()).toBe(false);
    const ui = TestBed.inject(UiStateService);
    expect(ui.get<boolean>(UI_STATE_KEYS.sidenavOpen, true)).toBe(false);
  });

  it('onSidenavOpenedChange does NOT persist on mobile', () => {
    // Pre-seed true so we can detect non-writes.
    const ui = TestBed.inject(UiStateService);
    ui.set<boolean>(UI_STATE_KEYS.sidenavOpen, true);

    const fixture = TestBed.createComponent(LayoutComponent);
    const cmp = fixture.componentInstance;
    // Flip to mobile.
    breakpointSubject.next({ matches: true, breakpoints: {} });
    expect(cmp.isMobile()).toBe(true);

    cmp.onSidenavOpenedChange(false);

    // Signal untouched, storage untouched.
    expect(cmp.sidenavOpen()).toBe(true);
    expect(ui.get<boolean>(UI_STATE_KEYS.sidenavOpen, false)).toBe(true);
  });
});
