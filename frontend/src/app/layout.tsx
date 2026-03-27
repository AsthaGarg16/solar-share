import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import './globals.css';
import { Providers } from '@/components/Providers';
import { Navbar } from '@/components/Navbar';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Solar Share — Decentralized Solar Financing',
  description:
    'Fund residential solar installations through fractional NFTs and earn dual yield: fixed monthly repayments + variable grid export revenue.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.className} bg-[#0a0e1a] text-slate-100 antialiased`}>
        <Providers>
          <Navbar />
          <main className="pt-16 min-h-screen">{children}</main>
        </Providers>
      </body>
    </html>
  );
}
