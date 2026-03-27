import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';

export const wagmiConfig = getDefaultConfig({
  appName: 'Solar Share',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'solar-share-demo',
  chains: [sepolia],
  ssr: true,
});
