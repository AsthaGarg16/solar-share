'use client';

import { useAccount } from 'wagmi';
import { contracts } from '@/contracts/addresses';
import { MockUSDABI } from '@/contracts/abis/MockUSDABI';
import { useMintUSDC, useUSDCBalance } from '@/hooks/useContracts';

const currentContracts = contracts.localhost;
const MINT_AMOUNT = BigInt(10_000 * 1_000_000); // 10,000 USDC (6 decimals)

export function MintButton() {
  const { address, isConnected } = useAccount();
  const { data: balance, refetch } = useUSDCBalance(address);
  const { writeContract: mint, isPending } = useMintUSDC();

  const handleMint = () => {
    if (!address) return;
    mint(
      {
        address: currentContracts.mockUSDC,
        abi: MockUSDABI,
        functionName: 'mint',
        args: [address, MINT_AMOUNT],
      },
      { onSuccess: () => setTimeout(() => refetch(), 2000) }
    );
  };

  const formatBalance = (bal: bigint | undefined) => {
    if (!bal) return '0.00';
    return (Number(bal) / 1e6).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  };

  if (!isConnected) return null;

  return (
    <div className="flex items-center gap-3">
      {balance !== undefined && (
        <span className="text-slate-400 text-sm">
          Balance: <span className="text-white font-medium">${formatBalance(balance)} mUSDC</span>
        </span>
      )}
      <button
        onClick={handleMint}
        disabled={isPending}
        className="bg-slate-700 hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed text-white text-sm font-medium py-2 px-4 rounded-lg transition-colors border border-slate-600"
      >
        {isPending ? (
          <span className="flex items-center gap-2">
            <svg className="animate-spin h-3.5 w-3.5" viewBox="0 0 24 24" fill="none">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            Minting...
          </span>
        ) : (
          'Get Test USDC'
        )}
      </button>
    </div>
  );
}
