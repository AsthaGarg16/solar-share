'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import Link from 'next/link';

export default function Navbar() {
  return (
    <nav className="border-b">
      <div className="container mx-auto px-4 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link href="/" className="text-2xl font-bold text-blue-600">
            ☀️ Solar Share
          </Link>

          {/* Navigation Links */}
          <div className="hidden md:flex items-center gap-8">
            <Link 
              href="/projects" 
              className="text-gray-600 hover:text-gray-900 transition"
            >
              Projects
            </Link>
            <Link 
              href="/portfolio" 
              className="text-gray-600 hover:text-gray-900 transition"
            >
              My Portfolio
            </Link>
            <Link 
              href="/governance" 
              className="text-gray-600 hover:text-gray-900 transition"
            >
              Governance
            </Link>
          </div>

          {/* Connect Wallet Button */}
          <ConnectButton />
        </div>
      </div>
    </nav>
  );
}