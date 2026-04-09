'use client';

import { useState, useEffect, useCallback } from 'react';
import { useAccount } from 'wagmi';
import { useReadContract } from 'wagmi';
import Link from 'next/link';
import { contracts } from '@/contracts/addresses';
import { SolarProjectABI } from '@/contracts/abis/SolarProjectABI';
import { RevenueDistributorABI } from '@/contracts/abis/RevenueDistributorABI';
import { MintButton } from '@/components/MintButton';
import { useUSDCBalance, useProjectCount, useClaimDividends } from '@/hooks/useContracts';
import { ClaimDividends } from '@/components/ClaimDividends';

const STATUS_LABELS: Record<number, string> = {
  0: 'Funding',
  1: 'Active',
  2: 'Defaulted',
  3: 'Bought Out',
};

type ProjectData = {
  projectId: bigint;
  host: string;
  targetAmount: bigint;
  amountRaised: bigint;
  totalShares: bigint;
  sharesSold: bigint;
  pricePerShare: bigint;
  termMonths: bigint;
  startDate: bigint;
  isFunded: boolean;
  isBoughtOut: boolean;
  status: number;
};

type InvestorPosition = {
  project: ProjectData;
  shares: bigint;
  claimable: bigint;
};

function PositionLoader({
  projectId,
  address,
  onLoaded,
}: {
  projectId: bigint;
  address: `0x${string}`;
  onLoaded: (id: bigint, shares: bigint, project: ProjectData, claimable: bigint) => void;
}) {
  // 💡 建议：这里应该使用你在 .env.local 中定义的本地地址，或者使用 contracts.localhost (如果有)
  // 为了确保本地能跑通，你可以先改成直接读取 .env 或对应的本地变量
  
  const { data: project } = useReadContract({
    address: contracts.localhost?.solarProject, // ✅ 优先本地
    abi: SolarProjectABI,
    functionName: 'getProjectDetails',
    args: [projectId],
  });

  const { data: shares } = useReadContract({
    address: contracts.localhost?.solarProject,
    abi: SolarProjectABI,
    functionName: 'getInvestorShares',
    args: [projectId, address],
  });

  const { data: claimable } = useReadContract({
    address: contracts.localhost?.revenueDistributor,
    abi: RevenueDistributorABI,
    functionName: 'getClaimableDividends',
    args: [projectId, address],
  });

  useEffect(() => {
    if (project && shares !== undefined && shares > 0n) {
      onLoaded(projectId, shares, project as ProjectData, (claimable ?? 0n) as bigint);
    }
  }, [project, shares, claimable, projectId, onLoaded]);

  return null;
}

export default function DashboardPage() {
  const { address, isConnected } = useAccount();

//   if (!isConnected) {
//     return (
//       <div className="max-w-4xl mx-auto px-4 py-24 text-center">
//         <div className="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-6">
//           <svg className="w-8 h-8 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
//             <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
//               d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
//             />
//           </svg>
//         </div>
//         <h1 className="text-2xl font-bold text-white mb-3">Connect Your Wallet</h1>
//         <p className="text-slate-400">Connect your wallet to view your investment portfolio.</p>
//       </div>
//     );
//   }

//   if (!address) return null;

//   return <ConnectedDashboard address={address} />;
// }

// function ConnectedDashboard({ address }: { address: `0x${string}` }) {
  const [positions, setPositions] = useState<Map<string, InvestorPosition>>(new Map());
  const [selectedProject, setSelectedProject] = useState<bigint | null>(null);

  const { data: usdcBalance } = useUSDCBalance(address);
  const { data: projectCount } = useProjectCount();

  const count = projectCount ? Number(projectCount) : 0;
  const projectIds = Array.from({ length: count }, (_, i) => BigInt(i + 1));

  const handlePositionLoaded = useCallback(
    (id: bigint, shares: bigint, project: ProjectData, claimable: bigint) => {
      setPositions((prev) => {
        const next = new Map(prev);
        next.set(id.toString(), { project, shares, claimable });
        return next;
      });
    },
    []
  );

  const allPositions = Array.from(positions.values());
  const totalInvested = allPositions.reduce(
    (sum, p) => sum + p.shares * p.project.pricePerShare,
    0n
  );
  const totalClaimable = allPositions.reduce((sum, p) => sum + p.claimable, 0n);

  const formatUSDC = (amount: bigint) =>
    (Number(amount) / 1e6).toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

<<<<<<< HEAD
  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-24 text-center">
        <div className="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <svg className="w-8 h-8 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
              d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z"
            />
          </svg>
        </div>
        <h1 className="text-2xl font-bold text-white mb-3">Connect Your Wallet</h1>
        <p className="text-slate-400">Connect your wallet to view your investment portfolio.</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Position Loaders */}
      {address && projectIds.map((id) => (
=======
  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Position Loaders */}
      {projectIds.map((id) => (
>>>>>>> origin/demo_default
        <PositionLoader
          key={id.toString()}
          projectId={id}
          address={address}
          onLoaded={handlePositionLoaded}
        />
      ))}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Investor Dashboard</h1>
          <p className="text-slate-500 text-sm mt-1 font-mono">
            {address?.slice(0, 6)}...{address?.slice(-4)}
          </p>
        </div>
        <MintButton />
      </div>

      {/* Portfolio Summary */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {[
          {
            label: 'USDC Balance',
            value: `$${formatUSDC(usdcBalance ?? 0n)}`,
            color: 'text-white',
          },
          {
            label: 'Total Invested',
            value: `$${formatUSDC(totalInvested)}`,
            color: 'text-white',
          },
          {
            label: 'Active Positions',
            value: allPositions.length.toString(),
            color: 'text-white',
          },
          {
            label: 'Total Claimable',
            value: `$${formatUSDC(totalClaimable)}`,
            color: 'text-green-400',
          },
        ].map((stat) => (
          <div
            key={stat.label}
            className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-5"
          >
            <p className="text-slate-500 text-xs mb-1">{stat.label}</p>
            <p className={`text-xl font-bold ${stat.color}`}>{stat.value}</p>
          </div>
        ))}
      </div>

      {/* Positions */}
      {allPositions.length === 0 ? (
        <div className="text-center py-20">
          <div className="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
              />
            </svg>
          </div>
          <h3 className="text-white font-semibold text-lg mb-2">No Investments Yet</h3>
          <p className="text-slate-400 text-sm mb-6">Browse projects and start earning yield.</p>
          <Link
            href="/explore"
            className="bg-green-600 hover:bg-green-500 text-white font-medium py-2.5 px-6 rounded-xl transition-colors"
          >
            Explore Projects
          </Link>
        </div>
      ) : (
        <div className="space-y-4">
          <h2 className="text-xl font-bold text-white mb-4">Your Positions</h2>
          {allPositions.map((pos) => {
            const ownership =
              pos.project.totalShares > 0n
                ? ((Number(pos.shares) / Number(pos.project.totalShares)) * 100).toFixed(2)
                : '0';

            return (
              <div
                key={pos.project.projectId.toString()}
                className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-5"
              >
                <div className="flex flex-col md:flex-row md:items-center gap-4">
                  {/* Project Info */}
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <h3 className="text-white font-semibold">
                        Project #{pos.project.projectId.toString()}
                      </h3>
                      <span className="text-xs px-2 py-0.5 rounded-full bg-slate-700 text-slate-400">
                        {STATUS_LABELS[pos.project.status]}
                      </span>
                    </div>
                    <div className="flex flex-wrap gap-4 text-sm">
                      <span className="text-slate-400">
                        Shares: <span className="text-white font-medium">{pos.shares.toString()}</span>
                      </span>
                      <span className="text-slate-400">
                        Ownership: <span className="text-white font-medium">{ownership}%</span>
                      </span>
                      <span className="text-slate-400">
                        Invested: <span className="text-white font-medium">
                          ${formatUSDC(pos.shares * pos.project.pricePerShare)}
                        </span>
                      </span>
                      <span className="text-slate-400">
                        Claimable: <span className="text-green-400 font-medium">
                          ${formatUSDC(pos.claimable)}
                        </span>
                      </span>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex gap-2">
                    <Link
                      href={`/projects/${pos.project.projectId}`}
                      className="bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
                    >
                      View
                    </Link>
                    {pos.claimable > 0n && (
                      <button
                        onClick={() => setSelectedProject(pos.project.projectId)}
                        className="bg-green-600 hover:bg-green-500 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
                      >
                        Claim ${formatUSDC(pos.claimable)}
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Quick Claim Modal */}
      {selectedProject !== null && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl p-6 w-full max-w-sm">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-white font-semibold">Claim Dividends</h3>
              <button
                onClick={() => setSelectedProject(null)}
                className="text-slate-400 hover:text-white"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <ClaimDividends projectId={selectedProject} />
          </div>
        </div>
      )}
    </div>
  );
}
