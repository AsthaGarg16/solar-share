'use client';

import { useState } from 'react';
import { useWriteContract, useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { contracts } from '@/contracts/addresses';
import { MaintenanceDAOABI } from '@/contracts/abis/MaintenanceDAOABI';

interface CreateProposalProps {
  onSuccess?: () => void;
}

export default function CreateProposal({ onSuccess }: CreateProposalProps) {
  const [projectId, setProjectId] = useState('');
  const [description, setDescription] = useState('');
  const [amount, setAmount] = useState('');
  const [vendor, setVendor] = useState('');
  const { writeContract, isPending } = useWriteContract();
  const { address } = useAccount();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!projectId || !description || !amount || !vendor) return;

    writeContract(
      {
        address: contracts.sepolia.maintenanceDAO,
        abi: MaintenanceDAOABI,
        functionName: 'submitProposal',
        args: [
          BigInt(projectId),
          description,
          parseUnits(amount, 6),
          vendor as `0x${string}`,
        ],
      },
      { onSuccess }
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
          disabled={isPending || !projectId || !description || !amount || !vendor}
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
