'use client';

import { useAccount } from 'wagmi';
import { contracts } from '@/contracts/addresses';
import { RevenueDistributorABI } from '@/contracts/abis/RevenueDistributorABI';
import { useClaimableDividends, useClaimDividends, useExecuteWaterfall } from '@/hooks/useContracts';

interface ClaimDividendsProps {
  projectId: bigint;
}

export function ClaimDividends({ projectId }: ClaimDividendsProps) {
  const { address, isConnected } = useAccount();

  const { data: claimable, isLoading, refetch } = useClaimableDividends(projectId, address);
  const { writeContract: claim, isPending: isClaiming } = useClaimDividends();
  const { writeContract: waterfall, isPending: isWaterfalling } = useExecuteWaterfall();

  const handleClaim = () => {
    if (!address) return;
    claim(
      {
        address: contracts.sepolia.revenueDistributor,
        abi: RevenueDistributorABI,
        functionName: 'claimDividends',
        args: [projectId],
      },
      { onSuccess: () => setTimeout(() => refetch(), 2000) }
    );
  };

  const handleWaterfall = () => {
    waterfall(
      {
        address: contracts.sepolia.revenueDistributor,
        abi: RevenueDistributorABI,
        functionName: 'executeWaterfall',
        args: [projectId],
      },
      { onSuccess: () => setTimeout(() => refetch(), 2000) }
    );
  };

  const formatUSDC = (amount: bigint) =>
    (Number(amount) / 1e6).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 6 });

  if (!isConnected) {
    return (
      <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 text-center">
        <p className="text-slate-400 text-sm">Connect wallet to view dividends</p>
      </div>
    );
  }

  return (
    <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
      <h3 className="text-white font-semibold text-lg mb-4">Your Dividends</h3>

      <div className="text-center py-4 mb-4">
        {isLoading ? (
          <div className="text-slate-400 text-sm">Loading...</div>
        ) : (
          <>
            <p className="text-slate-400 text-sm mb-1">Claimable</p>
            <p className="text-3xl font-bold text-green-400">
              ${formatUSDC(claimable ?? 0n)}
            </p>
            <p className="text-slate-500 text-xs mt-1">USDC</p>
          </>
        )}
      </div>

      <div className="space-y-2">
        <button
          onClick={handleClaim}
          disabled={isClaiming || !claimable || claimable === 0n}
          className="w-full bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-xl transition-colors"
        >
          {isClaiming ? (
            <span className="flex items-center justify-center gap-2">
              <LoadingSpinner />
              Claiming...
            </span>
          ) : (
            'Claim Dividends'
          )}
        </button>

        <button
          onClick={handleWaterfall}
          disabled={isWaterfalling}
          className="w-full bg-slate-700 hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed text-slate-300 text-sm font-medium py-2.5 px-4 rounded-xl transition-colors"
        >
          {isWaterfalling ? (
            <span className="flex items-center justify-center gap-2">
              <LoadingSpinner />
              Processing...
            </span>
          ) : (
            'Execute Revenue Waterfall'
          )}
        </button>
      </div>

      <p className="text-slate-600 text-xs mt-3 text-center">
        93% of all revenue distributed to shareholders
      </p>
    </div>
  );
}

function LoadingSpinner() {
  return (
    <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  );
}
