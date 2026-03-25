'use client';

import './globals.css';
import '@rainbow-me/rainbowkit/styles.css';
import { Inter } from 'next/font/google';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { config } from '@/config/wagmi';
import Header from '@/components/header';
import Sidebar from '@/components/sidebar';

const inter = Inter({ subsets: ['latin'] });

const queryClient = new QueryClient();

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            <RainbowKitProvider>
              <div className="min-h-screen bg-gray-50">
                <Header />
                <Sidebar />
                <main className="pt-16 pl-[72px] min-h-screen transition-all duration-300">
                  {children}
                </main>
              </div>
            </RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}