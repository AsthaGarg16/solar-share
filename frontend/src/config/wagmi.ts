import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { localhost } from 'wagmi/chains'; // 👈 这里增加了 localhost

import { defineChain } from 'viem'; // 👈 导入这个

// 自定义一个明确的 localhost 配置，防止歧义
const localAnvil = defineChain({
  id: 31337,
  name: 'Localhost',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
  },
});

export const wagmiConfig = getDefaultConfig({
  appName: 'Solar Share',
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'solar-share-demo',
  chains: [localAnvil], // 👈 使用我们定义的这个
  ssr: true,
});