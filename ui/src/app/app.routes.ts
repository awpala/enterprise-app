import { Routes } from '@angular/router';
import { MsalRedirectComponent } from '@azure/msal-angular';

import { authGuard, authGuardChild } from './auth/auth.guard';
import { LayoutComponent } from './shared/components/layout/layout.component';

export const routes: Routes = [
  // Public landing page — renders outside the app shell.
  {
    path: '',
    pathMatch: 'full',
    loadComponent: () =>
      import('./features/landing/landing.component').then(m => m.LandingComponent),
  },
  // MSAL posts the auth response to this route on the return hop. The
  // MsalRedirectComponent is a no-render component; the actual redirect
  // handling happens inside the MsalService via handleRedirectPromise.
  { path: 'auth/redirect', component: MsalRedirectComponent },
  {
    path: 'login-failed',
    loadComponent: () =>
      import('./auth/login-failed.component').then(m => m.LoginFailedComponent),
  },
  // Authenticated area: the LayoutComponent (toolbar + sidenav) only wraps
  // routes behind MsalGuard, so unauthenticated users never see app chrome.
  {
    path: '',
    component: LayoutComponent,
    canActivate: [authGuard],
    canActivateChild: [authGuardChild],
    children: [
      {
        path: 'dashboard',
        loadComponent: () =>
          import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent),
      },
      {
        path: 'models',
        children: [
          {
            path: '',
            loadComponent: () =>
              import('./features/models/model-list/model-list.component').then(m => m.ModelListComponent),
          },
          {
            path: 'new',
            loadComponent: () =>
              import('./features/models/model-form/model-form.component').then(m => m.ModelFormComponent),
          },
          {
            path: ':id',
            loadComponent: () =>
              import('./features/models/model-detail/model-detail.component').then(m => m.ModelDetailComponent),
          },
          {
            path: ':id/edit',
            loadComponent: () =>
              import('./features/models/model-form/model-form.component').then(m => m.ModelFormComponent),
          },
          {
            path: ':id/runs',
            children: [
              {
                path: '',
                loadComponent: () =>
                  import('./features/models/model-runs/model-runs.component').then(m => m.ModelRunsComponent),
              },
              {
                path: ':runId',
                loadComponent: () =>
                  import('./features/models/model-runs/run-detail/run-detail.component').then(m => m.RunDetailComponent),
              },
            ],
          },
        ],
      },
    ],
  },
  // Anything unknown falls back to the public landing (safe for unauthenticated).
  { path: '**', redirectTo: '' },
];
