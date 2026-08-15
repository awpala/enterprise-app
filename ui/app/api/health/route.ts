import { NextResponse } from 'next/server';

/** Returns the UI process liveness response. */
export function GET(): NextResponse {
  return NextResponse.json({ status: 'healthy', service: 'ea-ui' });
}
