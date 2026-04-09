import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { defineChain } from 'viem';
import { http } from 'viem';

// Custom Anvil chain configuration for local development
const localAnvil = defineChain({
  id: 31337,
  name: 'Localhost (Anvil)',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
  },
  testnet: true,
});

export const wagmiConfig = getDefaultConfig({
  appName: 'Solar Share',
  projectId: 'solar-share-dev', // Dummy project ID for local development
  chains: [localAnvil],
  transports: {
    [localAnvil.id]: http('http://127.0.0.1:8545'),
  },
  ssr: true,
});