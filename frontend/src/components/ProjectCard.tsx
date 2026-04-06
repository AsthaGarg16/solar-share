'use client';

import Link from 'next/link';

const STATUS_LABELS: Record<number, string> = {
  0: 'Funding',
  1: 'Active',
  2: 'Defaulted',
  3: 'Bought Out',
};

const STATUS_COLORS: Record<number, string> = {
  0: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  1: 'bg-green-500/20 text-green-400 border-green-500/30',
  2: 'bg-red-500/20 text-red-400 border-red-500/30',
  3: 'bg-slate-500/20 text-slate-400 border-slate-500/30',
};

interface ProjectCardProps {
  projectId: bigint;
  host: string;
  targetAmount: bigint;
  amountRaised: bigint;
  totalShares: bigint;
  sharesSold: bigint;
  pricePerShare: bigint;
  termMonths: bigint;
  isFunded: boolean;
  status: number;
}

function formatUSDC(amount: bigint): string {
  const num = Number(amount) / 1e6;
  if (num >= 1000) return `$${(num / 1000).toFixed(1)}k`;
  return `$${num.toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
}

export function ProjectCard({
  projectId,
  host,
  targetAmount,
  amountRaised,
  totalShares,
  sharesSold,
  pricePerShare,
  termMonths,
  isFunded,
  status,
}: ProjectCardProps) {
  const fundingPct = targetAmount > 0n
    ? Number((amountRaised * 100n) / targetAmount)
    : 0;
  const statusLabel = STATUS_LABELS[status] ?? 'Unknown';
  const statusColor = STATUS_COLORS[status] ?? STATUS_COLORS[0];

  return (
    <Link href={`/projects/${projectId}`}>
      <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 hover:border-green-500/40 hover:bg-slate-800/80 transition-all duration-200 cursor-pointer group">
        {/* Header */}
        <div className="flex items-start justify-between mb-4">
          <div>
            <h3 className="text-white font-semibold text-lg group-hover:text-green-400 transition-colors">
              Solar Project #{projectId.toString()}
            </h3>
            <p className="text-slate-500 text-xs mt-1 font-mono">
              {host.slice(0, 6)}...{host.slice(-4)}
            </p>
          </div>
          <span className={`text-xs font-medium px-2.5 py-1 rounded-full border ${statusColor}`}>
            {statusLabel}
          </span>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-3 mb-5">
          <div className="bg-slate-900/60 rounded-xl p-3">
            <p className="text-slate-500 text-xs mb-1">Target</p>
            <p className="text-white font-semibold">{formatUSDC(targetAmount)}</p>
          </div>
          <div className="bg-slate-900/60 rounded-xl p-3">
            <p className="text-slate-500 text-xs mb-1">Per Share</p>
            <p className="text-white font-semibold">{formatUSDC(pricePerShare)}</p>
          </div>
          <div className="bg-slate-900/60 rounded-xl p-3">
            <p className="text-slate-500 text-xs mb-1">Term</p>
            <p className="text-white font-semibold">{termMonths.toString()}mo</p>
          </div>
          <div className="bg-slate-900/60 rounded-xl p-3">
            <p className="text-slate-500 text-xs mb-1">Shares Left</p>
            <p className="text-white font-semibold">{(totalShares - sharesSold).toString()}</p>
          </div>
        </div>

        {/* Progress Bar */}
        <div>
          <div className="flex justify-between text-xs text-slate-400 mb-1.5">
            <span>{formatUSDC(amountRaised)} raised</span>
            <span>{fundingPct}%</span>
          </div>
          <div className="h-2 bg-slate-700 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-green-500 to-emerald-400 rounded-full transition-all duration-500"
              style={{ width: `${Math.min(fundingPct, 100)}%` }}
            />
          </div>
        </div>
      </div>
    </Link>
  );
}
