'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';

export default function Header() {
  return (
    <header className="fixed top-0 left-0 right-0 h-16 bg-white border-b border-gray-200 z-50">
      <div className="h-full px-6 flex items-center justify-between">
        {/* Logo/Brand */}
        <div className="flex items-center gap-2">
          <div className="text-3xl">☀️</div>
          <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
            SolarShare
          </h1>
        </div>

        {/* Connect Wallet Button */}
        <div>
          <ConnectButton />
        </div>
      </div>
    </header>
  );
}