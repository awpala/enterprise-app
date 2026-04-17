import { ErrorHandler, Injectable, inject } from '@angular/core';
import { SeverityLevel } from '@microsoft/applicationinsights-web';

import { AppInsightsService } from './app-insights.service';

@Injectable({ providedIn: 'root' })
export class AppInsightsErrorHandler implements ErrorHandler {
  private readonly appInsights = inject(AppInsightsService);

  handleError(error: unknown): void {
    const normalized = error instanceof Error ? error : new Error(String(error));
    this.appInsights.trackException(normalized, SeverityLevel.Error);
    console.error(normalized);
  }
}
