'use client';

import { useMemo } from 'react';
import { ApiClient } from './api';
import { useAuth } from '@/components/AuthProvider';

export function useApi(): ApiClient | null {
  const { config, getAccessToken } = useAuth();
  return useMemo(
    () => config ? new ApiClient(config.apiUrl, getAccessToken) : null,
    [config, getAccessToken],
  );
}
