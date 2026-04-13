import { bootstrapApplication } from '@angular/platform-browser';

import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

/**
 * Single-bootstrap MSAL Angular pattern.
 *
 * `AppComponent` is the sole bootstrapped component; it renders into
 * `<app-root>` in index.html. The redirect-response hop is handled by the
 * router activating the `/auth/redirect` route (see `app.routes.ts`), which
 * mounts `MsalRedirectComponent` inside the same application injector.
 *
 * We intentionally do NOT call `bootstrapApplication(MsalRedirectComponent, ...)`
 * separately. Doing so spins up a second, independent Angular injector tree,
 * which produces a second `MsalService` / `MSAL_INSTANCE` pair. Both instances
 * race to call `handleRedirectPromise()` on the same URL fragment, leading to
 * "interaction in progress" errors, lost tokens, and redirect loops on logout.
 * Owning the redirect via the route keeps everything on one injector and one
 * MSAL singleton.
 */
bootstrapApplication(AppComponent, appConfig).catch((err) =>
  // eslint-disable-next-line no-console
  console.error(err),
);
