'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { contracts } from '@/contracts/addresses';
import { SolarProjectABI } from '@/contracts/abis/SolarProjectABI';
import { MockUSDABI } from '@/contracts/abis/MockUSDABI';
import {
  useUSDCAllowance,
  useApproveUSDC,
  useFundProject,
} from '@/hooks/useContracts';

interface InvestWidgetProps {
  projectId: bigint;
  pricePerShare: bigint;
  sharesAvailable: bigint;
}

export function InvestWidget({ projectId, pricePerShare, sharesAvailable }: InvestWidgetProps) {
  const { address, isConnected } = useAccount();
  const [numShares, setNumShares] = useState('');

  const sharesNum = BigInt(numShares || '0');
  const totalCost = sharesNum * pricePerShare;

  const { data: allowance, refetch: refetchAllowance } = useUSDCAllowance(
    address,
    contracts.sepolia.solarProject
  );

  const needsApproval = !allowance || allowance < totalCost;

  const { writeContract: approve, isPending: isApproving } = useApproveUSDC();
  const { writeContract: fund, isPending: isFunding } = useFundProject();

  const handleApprove = () => {
    if (!address) return;
    approve(
      {
        address: contracts.sepolia.mockUSDC,
        abi: MockUSDABI,
        functionName: 'approve',
        args: [contracts.sepolia.solarProject, totalCost],
      },
      {
        onSuccess: () => {
          setTimeout(() => refetchAllowance(), 2000);
        },
      }
    );
  };

  const handleFund = () => {
    if (!address || sharesNum === 0n) return;
    fund({
      address: contracts.sepolia.solarProject,
      abi: SolarProjectABI,
      functionName: 'fundProject',
      args: [projectId, sharesNum],
    });
  };

  const formatUSDC = (amount: bigint) =>
    `$${(Number(amount) / 1e6).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

  if (!isConnected) {
    return (
      <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 text-center">
        <p className="text-slate-400 text-sm">Connect your wallet to invest</p>
      </div>
    );
  }

  return (
    <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
      <h3 className="text-white font-semibold text-lg mb-4">Invest in This Project</h3>

      <div className="space-y-4">
        <div>
          <label className="text-slate-400 text-sm mb-1.5 block">Number of Shares</label>
          <input
            type="number"
            min="1"
            max={sharesAvailable.toString()}
            value={numShares}
            onChange={(e) => setNumShares(e.target.value)}
            placeholder="Enter shares"
            className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 focus:ring-1 focus:ring-green-500/20 transition-colors"
          />
          <p className="text-slate-500 text-xs mt-1">
            {sharesAvailable.toString()} shares available @ {formatUSDC(pricePerShare)} each
          </p>
        </div>

        {numShares && sharesNum > 0n && (
          <div className="bg-green-500/10 border border-green-500/20 rounded-xl p-3">
            <div className="flex justify-between text-sm">
              <span className="text-slate-400">Total Cost</span>
              <span className="text-green-400 font-semibold">{formatUSDC(totalCost)}</span>
            </div>
            <div className="flex justify-between text-sm mt-1">
              <span className="text-slate-400">Your Ownership</span>
              <span className="text-white">
                {sharesAvailable > 0n
                  ? ((Number(sharesNum) / Number(sharesAvailable + sharesNum)) * 100).toFixed(2)
                  : '0'}%
              </span>
            </div>
          </div>
        )}

        <div className="space-y-2">
          {needsApproval ? (
            <button
              onClick={handleApprove}
              disabled={isApproving || sharesNum === 0n}
              className="w-full bg-slate-700 hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-xl transition-colors"
            >
              {isApproving ? (
                <span className="flex items-center justify-center gap-2">
                  <LoadingSpinner />
                  Approving USDC...
                </span>
              ) : (
                '1. Approve USDC'
              )}
            </button>
          ) : null}

          <button
            onClick={handleFund}
            disabled={isFunding || sharesNum === 0n || needsApproval}
            className="w-full bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-xl transition-colors"
          >
            {isFunding ? (
              <span className="flex items-center justify-center gap-2">
                <LoadingSpinner />
                Investing...
              </span>
            ) : needsApproval ? (
              '2. Invest'
            ) : (
              'Invest Now'
            )}
          </button>
        </div>
      </div>
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
