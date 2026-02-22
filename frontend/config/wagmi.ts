import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, polygon, polygonMumbai } from 'wagmi/chains';

export const config = getDefaultConfig({
  appName: 'Solar Share',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID!,
  chains: [
    sepolia,      // Ethereum testnet (for development)
    polygon,      // Polygon mainnet (for production)
    polygonMumbai // Polygon testnet (alternative to Sepolia)
  ],
  ssr: true, // Enable server-side rendering
});