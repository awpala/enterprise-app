import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  agentRules: false,
  output: 'standalone',
  reactStrictMode: true,
  poweredByHeader: false,
};

export default nextConfig;
