export const RevenueDistributorABI = [
  {
    type: 'function',
    name: 'depositGridRevenue',
    inputs: [
      { name: 'projectId', type: 'uint256' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'executeWaterfall',
    inputs: [{ name: 'projectId', type: 'uint256' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'claimDividends',
    inputs: [{ name: 'projectId', type: 'uint256' }],
    outputs: [{ name: 'claimed', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getClaimableDividends',
    inputs: [
      { name: 'projectId', type: 'uint256' },
      { name: 'investor', type: 'address' },
    ],
    outputs: [{ name: 'claimable', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'projectRevenue',
    inputs: [{ name: '', type: 'uint256' }],
    outputs: [
      { name: 'totalRevenue', type: 'uint256' },
      { name: 'dividendPool', type: 'uint256' },
      { name: 'maintenanceReserve', type: 'uint256' },
      { name: 'insurancePool', type: 'uint256' },
      { name: 'dividendPerShare', type: 'uint256' },
      { name: 'lastWaterfallTimestamp', type: 'uint256' },
      { name: 'currentMonth', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'claimedDividends',
    inputs: [
      { name: '', type: 'uint256' },
      { name: '', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'DividendsClaimed',
    inputs: [
      { name: 'projectId', type: 'uint256', indexed: true },
      { name: 'investor', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'WaterfallExecuted',
    inputs: [
      { name: 'projectId', type: 'uint256', indexed: true },
      { name: 'totalRevenue', type: 'uint256', indexed: false },
      { name: 'dividendAmount', type: 'uint256', indexed: false },
      { name: 'maintenanceAmount', type: 'uint256', indexed: false },
      { name: 'insuranceAmount', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'GridRevenueDeposited',
    inputs: [
      { name: 'projectId', type: 'uint256', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
      { name: 'timestamp', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
] as const;