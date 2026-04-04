'use client';

import { useBlock } from 'wagmi';
import { useAccount } from 'wagmi';
import { useProposal, useHasVotedOnProposal, useVotingPower, useCastVote, useExecuteProposal } from '@/hooks/useContracts';
import { contracts } from '@/contracts/addresses';
import { MaintenanceDAOABI } from '@/contracts/abis/MaintenanceDAOABI';
import { formatUnits } from 'viem';

const currentContracts = contracts.localhost;
const STATUS_LABELS = ['Active', 'Passed', 'Rejected', 'Executed'];
const STATUS_COLORS = ['text-blue-400', 'text-green-400', 'text-red-400', 'text-purple-400'];

export default function ProposalCard({ proposalId }: { proposalId: bigint }) {
  const { address } = useAccount();
  const { data: proposal, refetch } = useProposal(proposalId);
  const { data: hasVoted } = useHasVotedOnProposal(proposalId, address);
  const { data: votingPower } = useVotingPower(
    proposal ? BigInt(proposal.projectId) : 0n,
    address
  );
  const { writeContract: castVoteWrite, isPending: isVotePending } = useCastVote();
  const { writeContract: executeWrite, isPending: isExecPending } = useExecuteProposal();
  const { data: block } = useBlock({ watch: true });

  if (!proposal || proposal.proposalId === 0n) return null;

  const now = block?.timestamp ? Number(block.timestamp) : Math.floor(Date.now() / 1000);
  const deadline = Number(proposal.votingDeadline);
  const isActive = proposal.status === 0;
  const votingEnded = now > deadline;
  const totalVotes = Number(proposal.yesVotes) + Number(proposal.noVotes);
  const yesPercent = totalVotes > 0 ? Math.round((Number(proposal.yesVotes) * 100) / totalVotes) : 0;

  const handleVote = (support: boolean) => {
    castVoteWrite(
      {
        address: currentContracts.maintenanceDAO,
        abi: MaintenanceDAOABI,
        functionName: 'castVote',
        args: [proposalId, support],
      },
      { onSuccess: () => refetch() }
    );
  };

  const handleExecute = () => {
    executeWrite(
      {
        address: currentContracts.maintenanceDAO,
        abi: MaintenanceDAOABI,
        functionName: 'executeProposal',
        args: [proposalId],
      },
      { onSuccess: () => refetch() }
    );
  };

  return (
    <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 space-y-4">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-white font-semibold text-lg">Proposal #{Number(proposalId)}</h3>
          <p className="text-slate-400 text-sm mt-0.5">Project #{Number(proposal.projectId)}</p>
        </div>
        <span className={`text-sm font-medium px-2.5 py-1 rounded-full bg-slate-700/60 ${STATUS_COLORS[proposal.status]}`}>
          {STATUS_LABELS[proposal.status]}
        </span>
      </div>

      {/* Description */}
      <p className="text-slate-300">{proposal.description}</p>

      {/* Details grid */}
      <div className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <p className="text-slate-400">Amount Requested</p>
          <p className="text-white font-semibold">${formatUnits(proposal.amount, 6)} USDC</p>
        </div>
        <div>
          <p className="text-slate-400">Vendor</p>
          <p className="text-white font-mono text-xs">{proposal.vendor.slice(0, 10)}...</p>
        </div>
        <div>
          <p className="text-slate-400">Voting Deadline</p>
          <p className="text-white">{new Date(deadline * 1000).toLocaleDateString()}</p>
        </div>
        <div>
          <p className="text-slate-400">Your Voting Power</p>
          <p className="text-white">{Number(votingPower ?? 0n)} tokens</p>
        </div>
      </div>

      {/* Vote tally */}
      <div className="space-y-1.5">
        <div className="flex justify-between text-sm">
          <span className="text-green-400">YES: {Number(proposal.yesVotes)}</span>
          <span className="text-red-400">NO: {Number(proposal.noVotes)}</span>
        </div>
        <div className="w-full h-2 bg-slate-700 rounded-full overflow-hidden">
          <div className="h-full bg-green-500 transition-all" style={{ width: `${yesPercent}%` }} />
        </div>
        <p className="text-xs text-slate-400">Need &gt;50% YES to pass ({yesPercent}% currently)</p>
      </div>

      {/* Actions */}
      {isActive && !votingEnded && address && !hasVoted && Number(votingPower) > 0 && (
        <div className="flex gap-3 pt-1">
          <button
            onClick={() => handleVote(true)}
            disabled={isVotePending}
            className="flex-1 bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-2.5 px-4 rounded-xl transition-colors"
          >
            Vote YES
          </button>
          <button
            onClick={() => handleVote(false)}
            disabled={isVotePending}
            className="flex-1 border border-red-500/60 text-red-400 hover:bg-red-900/20 disabled:opacity-50 disabled:cursor-not-allowed font-medium py-2.5 px-4 rounded-xl transition-colors"
          >
            Vote NO
          </button>
        </div>
      )}

      {isActive && !votingEnded && hasVoted && (
        <p className="text-slate-500 text-sm text-center pt-1">You have already voted on this proposal.</p>
      )}

      {isActive && votingEnded && (
        <button
          onClick={handleExecute}
          disabled={isExecPending}
          className="w-full bg-purple-600 hover:bg-purple-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium py-3 px-4 rounded-xl transition-colors mt-1"
        >
          {isExecPending ? (
            <span className="flex items-center justify-center gap-2">
              <LoadingSpinner />
              Executing...
            </span>
          ) : (
            'Execute Proposal'
          )}
        </button>
      )}
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
