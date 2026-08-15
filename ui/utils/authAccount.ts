import type { User } from 'oidc-client-ts';

/** Normalized identity displayed by the application shell. */
export interface AuthAccount {
  readonly name: string;
  readonly email: string;
  readonly identityProvider: string;
  readonly synthetic: 'dev' | 'guest' | null;
}

/** Normalizes provider-specific OIDC claims into the application account shape. */
export function accountFromUser(user: User): AuthAccount {
  const profile = user.profile;
  const identities = profile.identities;
  let identityProvider = typeof profile.idp === 'string' ? profile.idp : 'email';

  if (typeof identities === 'string') {
    try {
      const parsed = JSON.parse(identities) as Array<{ providerName?: string }>;
      identityProvider = parsed[0]?.providerName ?? identityProvider;
    } catch {
      // Optional display metadata does not affect the authenticated session.
    }
  }

  return {
    name: typeof profile.name === 'string'
      ? profile.name
      : typeof profile.preferred_username === 'string'
        ? profile.preferred_username
        : 'Signed-in user',
    email: typeof profile.email === 'string'
      ? profile.email
      : typeof profile.preferred_username === 'string'
        ? profile.preferred_username
        : '',
    identityProvider,
    synthetic: null,
  };
}
