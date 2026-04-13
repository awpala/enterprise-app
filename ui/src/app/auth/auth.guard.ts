import { inject } from '@angular/core';
import { CanActivateFn, CanActivateChildFn, Router } from '@angular/router';
import { MsalGuard } from '@azure/msal-angular';

import { AuthService } from './auth.service';

/**
 * Route guard for the authenticated area. Resolution order:
 *   1. Active synthetic dev session → allow.
 *   2. MSAL is configured           → delegate to MsalGuard.
 *   3. Otherwise                    → redirect to the public landing.
 */
export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isDevSession()) {
    return true;
  }
  if (auth.isMsalConfigured) {
    return inject(MsalGuard).canActivate(route, state);
  }
  return router.parseUrl('/');
};

export const authGuardChild: CanActivateChildFn = (route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isDevSession()) {
    return true;
  }
  if (auth.isMsalConfigured) {
    return inject(MsalGuard).canActivate(route, state);
  }
  return router.parseUrl('/');
};
