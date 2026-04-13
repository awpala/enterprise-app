import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import {
  ApplicationInsights,
  ITelemetryItem,
  SeverityLevel,
} from '@microsoft/applicationinsights-web';
import { AngularPlugin } from '@microsoft/applicationinsights-angularplugin-js';

import { environment } from '../environments/environment';

@Injectable({ providedIn: 'root' })
export class AppInsightsService {
  private appInsights: ApplicationInsights | null = null;
  private readonly angularPlugin = new AngularPlugin();

  initialize(router: Router): void {
    const connectionString = environment.applicationInsightsConnectionString;
    if (!connectionString) {
      return;
    }
    if (this.appInsights) {
      return;
    }

    this.appInsights = new ApplicationInsights({
      config: {
        connectionString,
        enableAutoRouteTracking: false,
        extensions: [this.angularPlugin],
        extensionConfig: {
          [this.angularPlugin.identifier]: { router },
        },
        disableFetchTracking: false,
        enableCorsCorrelation: true,
        enableRequestHeaderTracking: true,
        enableResponseHeaderTracking: true,
      },
    });

    this.appInsights.loadAppInsights();

    // cloud_RoleName drives the node label shown in App Insights Application Map;
    // pinning it to "ea-ui" keeps the SPA distinct from the API ("ea-api") and
    // the data engine so the end-to-end correlated topology renders correctly.
    this.appInsights.addTelemetryInitializer((item: ITelemetryItem): void => {
      item.tags ??= {};
      item.tags['ai.cloud.role'] = 'ea-ui';
    });

    this.appInsights.trackPageView();
  }

  trackException(error: Error, severityLevel?: SeverityLevel): void {
    if (!this.appInsights) {
      return;
    }
    this.appInsights.trackException({
      exception: error,
      severityLevel: severityLevel ?? SeverityLevel.Error,
    });
  }
}
