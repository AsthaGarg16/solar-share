export const MockGridOracleABI = [
  {
    type: 'function',
    name: 'submitGridRevenue',
    inputs: [{ name: 'projectId', type: 'uint256' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'submitFixedRevenue',
    inputs: [
      { name: 'projectId', type: 'uint256' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const;

