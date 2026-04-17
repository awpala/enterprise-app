/**
 * Development environment configuration.
 * Points to the local API running in Docker.
 *
 * The AAD_* values here are placeholders for local dev against a dev External
 * ID tenant — override by regenerating via scripts/generate-environment.mjs
 * or by editing this file locally (it is NOT gitignored). Empty strings
 * short-circuit MSAL initialization to a no-op friendly state.
 */
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  aadAuthority: '',
  aadClientId: '',
  aadTenantId: '',
  aadApiScope: '',
  /**
   * Enables the "Log in as Dev" button on the landing page — a synthetic
   * session matching the backend's DevAuthHandler sentinel principal.
   * Local dev and the deployed `dev` environment set this to true; prod
   * leaves it false (see .github/workflows/deploy.yml).
   */
  enableDevAuth: true,
  /**
   * Enables the "Log in as Guest" button on the landing page — a synthetic
   * demo session matching the backend's guest sentinel principal. Prod-only
   * affordance for sales/demo prospects; local dev and deployed `dev` leave
   * this false (Dev and Guest are independent, not derived from each other).
   */
  enableGuestAuth: false,
  applicationInsightsConnectionString: '',
};
