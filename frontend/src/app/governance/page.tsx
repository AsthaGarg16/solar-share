'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useProposalCount, useProposal } from '@/hooks/useContracts';
import CreateProposal from '@/components/CreateProposal';
import ProposalCard from '@/components/ProposalCard';
function ProposalList({ count }: { count: number }) {
  return (
    <div className="space-y-4">
      {Array.from({ length: count }, (_, i) => count - i).map((id) => (
        <ProposalCard key={id} proposalId={BigInt(id)} />
      ))}
    </div>
  );
}

export default function GovernancePage() {
  const { isConnected } = useAccount();
  const [showCreate, setShowCreate] = useState(false);
  const { data: count } = useProposalCount();
  const proposalCount = Number(count ?? 0n);

  return (
    <div className="min-h-screen bg-slate-900 pt-20">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white">Governance</h1>
            <p className="text-slate-400 mt-1">Vote on maintenance proposals for solar projects</p>
          </div>
          {isConnected && (
            <button
              onClick={() => setShowCreate(!showCreate)}
              className="bg-green-600 hover:bg-green-500 text-white font-medium px-4 py-2 rounded-xl transition-colors text-sm"
            >
              {showCreate ? 'Cancel' : 'Create Proposal'}
            </button>
          )}
        </div>

        {showCreate && (
          <div className="mb-8">
            <CreateProposal onSuccess={() => setShowCreate(false)} />
          </div>
        )}

        {proposalCount === 0 ? (
          <div className="text-center py-16 text-slate-400">
            <div className="text-4xl mb-4">🗳</div>
            <p className="text-lg">No proposals yet.</p>
            <p className="text-sm mt-1">Create the first maintenance proposal.</p>
          </div>
        ) : (
          <ProposalList count={proposalCount} />
        )}
      </div>
    </div>
  );
}
