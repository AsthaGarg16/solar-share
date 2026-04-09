'use client';

import { useEffect, useState } from 'react';
import { useWriteContract, useAccount, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { contracts } from '@/contracts/addresses';
import { MaintenanceDAOABI } from '@/contracts/abis/MaintenanceDAOABI';
import { useMaintenanceReserve } from '@/hooks/useContracts';
import { MockUSDABI } from '@/contracts/abis/MockUSDABI';
import { MockGridOracleABI } from '@/contracts/abis/MockGridOracleABI';

const currentContracts = contracts.localhost;
const SEED_REVENUE = parseUnits('10000', 6); // $10,000 -> adds ~$500 to maintenance reserve (5%)

interface CreateProposalProps {
  onSuccess?: () => void;
}

export default function CreateProposal({ onSuccess }: CreateProposalProps) {
  const [projectId, setProjectId] = useState('');
  const [description, setDescription] = useState('');
  const [amount, setAmount] = useState('');
  const [vendor, setVendor] = useState('');
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [seedProjectId, setSeedProjectId] = useState<bigint>(0n);
  const [depositSubmitted, setDepositSubmitted] = useState(false);
  const { writeContract, isPending } = useWriteContract();
  const { writeContract: mintToOracle, data: mintHash, isPending: isMintPending } = useWriteContract();
  const { writeContract: depositRevenue, data: depositHash, isPending: isDepositPending } =
    useWriteContract();
  const { address } = useAccount();

  const parsedProjectId = projectId ? BigInt(projectId) : 0n;
  const { data: reserve, refetch: refetchReserve } = useMaintenanceReserve(parsedProjectId);

  const parsedAmount =
    amount && amount.trim().length > 0 ? parseUnits(amount, 6) : 0n;
  const reserveAmount = reserve ?? 0n;
  const amountExceedsReserve = parsedProjectId > 0n && parsedAmount > reserveAmount;

  const { isSuccess: isMintConfirmed } = useWaitForTransactionReceipt({
    hash: mintHash,
    query: { enabled: !!mintHash },
  });
  const { isSuccess: isDepositConfirmed } = useWaitForTransactionReceipt({
    hash: depositHash,
    query: { enabled: !!depositHash },
  });

  const isSeeding =
    isMintPending || isDepositPending || (depositSubmitted && !isDepositConfirmed);

  const handleSeedReserve = () => {
    if (parsedProjectId === 0n) return;
    setSubmitError(null);
    setSeedProjectId(parsedProjectId);
    setDepositSubmitted(false);

    // 1) Mint USDC to the mock oracle so it can `transferFrom` into the distributor
    mintToOracle(
      {
        address: currentContracts.mockUSDC,
        abi: MockUSDABI,
        functionName: 'mint',
        args: [currentContracts.mockGridOracle, SEED_REVENUE],
      },
      {
        onError: (err) => setSubmitError(err instanceof Error ? err.message : String(err)),
      }
    );
  };

  useEffect(() => {
    if (!isMintConfirmed || seedProjectId === 0n || depositSubmitted) return;
    setDepositSubmitted(true);
    depositRevenue(
      {
        address: currentContracts.mockGridOracle,
        abi: MockGridOracleABI,
        functionName: 'submitFixedRevenue',
        args: [seedProjectId, SEED_REVENUE],
      },
      { onError: (err) => setSubmitError(err instanceof Error ? err.message : String(err)) }
    );
  }, [depositRevenue, depositSubmitted, isMintConfirmed, seedProjectId]);

  useEffect(() => {
    if (!depositSubmitted || !isDepositConfirmed) return;
    setSeedProjectId(0n);
    setDepositSubmitted(false);
    setTimeout(() => refetchReserve(), 1500);
  }, [depositSubmitted, isDepositConfirmed, refetchReserve]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitError(null);
    if (!projectId || !description || !amount || !vendor) return;
    if (amountExceedsReserve) return;

    writeContract(
      {
        address: currentContracts.maintenanceDAO,
        abi: MaintenanceDAOABI,
        functionName: 'submitProposal',
        args: [
          parsedProjectId,
          description,
          parsedAmount,
          vendor as `0x${string}`,
        ],
      },
      {
        onSuccess,
        onError: (err) => setSubmitError(err instanceof Error ? err.message : String(err)),
      }
    );
  };

  if (!address) {
    return (
      <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 text-center">
        <p className="text-slate-400 text-sm">Connect your wallet to create a proposal.</p>
      </div>
    );
  }

  return (
    <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
      <h3 className="text-white font-semibold text-lg mb-5">Create Maintenance Proposal</h3>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="text-slate-400 text-sm mb-1.5 block">Project ID</label>
          <input
            type="number"
            value={projectId}
            onChange={(e) => setProjectId(e.target.value)}
            placeholder="e.g. 1"
            className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 focus:ring-1 focus:ring-green-500/20 transition-colors"
          />
        </div>
        <div>
          <label className="text-slate-400 text-sm mb-1.5 block">Description</label>
          <input
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="e.g. Replace damaged inverter"
            className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 focus:ring-1 focus:ring-green-500/20 transition-colors"
          />
        </div>
        <div>
          <label className="text-slate-400 text-sm mb-1.5 block">Amount (USDC)</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="e.g. 500"
            className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 focus:ring-1 focus:ring-green-500/20 transition-colors"
          />
          <p className="text-slate-500 text-xs mt-1">
            Maintenance reserve for project {projectId || '…'}: $
            {formatUnits(reserveAmount, 6)}
          </p>
          {reserveAmount === 0n && parsedProjectId > 0n && (
            <div className="mt-2">
              <button
                type="button"
                onClick={handleSeedReserve}
                disabled={isSeeding}
                className="text-xs bg-slate-700 hover:bg-slate-600 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-2 px-3 rounded-lg transition-colors border border-slate-600"
              >
                {isSeeding ? 'Seeding...' : 'Seed reserve (local demo)'}
              </button>
              <p className="text-slate-500 text-xs mt-1">
                Mints $10,000 mUSDC to the mock grid oracle and deposits it as revenue (+~$500 reserve).
              </p>
            </div>
          )}
          {amountExceedsReserve && (
            <p className="text-red-400 text-xs mt-1">
              Amount exceeds maintenance reserve. Generate revenue first (host payment / grid revenue) or request a smaller amount.
            </p>
          )}
        </div>
        <div>
          <label className="text-slate-400 text-sm mb-1.5 block">Vendor Address</label>
          <input
            type="text"
            value={vendor}
            onChange={(e) => setVendor(e.target.value)}
            placeholder="0x..."
            className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 focus:ring-1 focus:ring-green-500/20 transition-colors font-mono text-sm"
          />
        </div>
        <button
          type="submit"
          disabled={isPending || !projectId || !description || !amount || !vendor || amountExceedsReserve}
          className="w-full bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-xl transition-colors"
        >
          {isPending ? (
            <span className="flex items-center justify-center gap-2">
              <LoadingSpinner />
              Submitting...
            </span>
          ) : (
            'Submit Proposal'
          )}
        </button>
        {submitError && (
          <div className="bg-red-500/10 border border-red-500/30 rounded-xl px-4 py-3 text-sm text-red-200">
            {submitError}
          </div>
        )}
      </form>
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
