import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
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
  { path: '**', redirectTo: 'dashboard' },
];
