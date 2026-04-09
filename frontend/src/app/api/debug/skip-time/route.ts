import { NextRequest, NextResponse } from 'next/server';

/**
 * POST /api/debug/skip-time
 * Skips forward time on local Anvil network
 * 
 * Body: { seconds: number }
 * 
 * Example: Skip 15 days = 15 * 86400 = 1,296,000 seconds
 */
export async function POST(request: NextRequest) {
  // Only allow in development
  if (process.env.NODE_ENV !== 'development') {
    return NextResponse.json(
      { error: 'This endpoint is only available in development' },
      { status: 403 }
    );
  }

  try {
    const { seconds } = await request.json();

    if (!seconds || typeof seconds !== 'number') {
      return NextResponse.json(
        { error: 'Invalid seconds parameter' },
        { status: 400 }
      );
    }

    const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL || 'http://127.0.0.1:8545';

    // Call anvil_increaseTime
    const timeResponse = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'anvil_increaseTime',
        params: [seconds],
        id: 1,
      }),
    });

    const timeData = await timeResponse.json();

    // Mine a block to apply the time change
    const mineResponse = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'anvil_mine',
        params: [1], // Mine 1 block
        id: 2,
      }),
    });

    const mineData = await mineResponse.json();

    // Get current block number
    const blockResponse = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'eth_blockNumber',
        params: [],
        id: 3,
      }),
    });

    const blockData = await blockResponse.json();

    return NextResponse.json({
      success: true,
      secondsSkipped: seconds,
      daysSkipped: Math.floor(seconds / 86400),
      blockNumber: parseInt(blockData.result, 16),
      message: `⏭️ Skipped ${Math.floor(seconds / 86400)} days forward`,
    });
  } catch (error) {
    console.error('Error skipping time:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}
