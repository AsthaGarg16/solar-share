export const HostReputationABI = [
  {
    type: 'function',
    name: 'mintSbt',
    inputs: [{ name: 'host', type: 'address' }],
    outputs: [{ name: 'tokenId', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getScore',
    inputs: [{ name: 'host', type: 'address' }],
    outputs: [{ name: 'score', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getReputationDetails',
    inputs: [{ name: 'host', type: 'address' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'score', type: 'uint256' },
          { name: 'projectsCreated', type: 'uint256' },
          { name: 'projectsCompleted', type: 'uint256' },
          { name: 'projectsDefaulted', type: 'uint256' },
          { name: 'totalSlashed', type: 'uint256' },
          { name: 'exists', type: 'bool' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'hostScores',
    inputs: [{ name: '', type: 'address' }],
    outputs: [
      { name: 'score', type: 'uint256' },
      { name: 'projectsCreated', type: 'uint256' },
      { name: 'projectsCompleted', type: 'uint256' },
      { name: 'projectsDefaulted', type: 'uint256' },
      { name: 'totalSlashed', type: 'uint256' },
      { name: 'exists', type: 'bool' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'hostToTokenId',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'SBTMinted',
    inputs: [
      { name: 'host', type: 'address', indexed: true },
      { name: 'tokenId', type: 'uint256', indexed: true },
      { name: 'initialScore', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'ScoreSlashed',
    inputs: [
      { name: 'host', type: 'address', indexed: true },
      { name: 'penaltyAmount', type: 'uint256', indexed: false },
      { name: 'newScore', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
] as const;
