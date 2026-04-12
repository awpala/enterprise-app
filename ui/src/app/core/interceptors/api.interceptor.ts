import { HttpInterceptorFn } from '@angular/common/http';

/**
 * HTTP interceptor placeholder.
 * Auth headers (MSAL Bearer token) will be added here in a future iteration.
 */
export const apiInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req);
};
