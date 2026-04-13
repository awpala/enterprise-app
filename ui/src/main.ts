import { bootstrapApplication } from '@angular/platform-browser';
import { MsalRedirectComponent } from '@azure/msal-angular';

import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';

/**
 * Standard MSAL Angular standalone bootstrap pattern.
 *
 * `AppComponent` renders into `<app-root>` as usual. `MsalRedirectComponent`
 * renders into `<app-redirect>` in index.html and is responsible for handling
 * the implicit/auth-code redirect response hop inside a hidden iframe —
 * without it, redirect-mode login cannot complete silent token acquisition.
 *
 * Both bootstraps share the same `appConfig` providers so MSAL singletons
 * (MsalService, MsalBroadcastService, MSAL_INSTANCE) are consistent.
 */
bootstrapApplication(AppComponent, appConfig).catch((err) =>
  // eslint-disable-next-line no-console
  console.error(err),
);

bootstrapApplication(MsalRedirectComponent, appConfig).catch((err) =>
  // eslint-disable-next-line no-console
  console.error(err),
);
