'use client';

import { useParams } from 'next/navigation';
import { useAccount } from 'wagmi';
import Link from 'next/link';
import {
  useProjectDetails,
  useProjectLoan,
  useInvestorShares,
  useClaimableDividends,
  useCheckDefaultStatus,
  useEquitySplit,
  useProjectRevenue,
  useDeclareDefault,
} from '@/hooks/useContracts';
import { InvestWidget } from '@/components/InvestWidget';
import { ClaimDividends } from '@/components/ClaimDividends';
import { contracts } from '@/contracts/addresses';
import { LoanManagerABI } from '@/contracts/abis/LoanManagerABI';

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

function formatUSDC(amount: bigint): string {
  return (Number(amount) / 1e6).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatDate(ts: bigint): string {
  if (ts === 0n) return '—';
  return new Date(Number(ts) * 1000).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

export default function ProjectDetailPage() {
  const params = useParams();
  const projectId = BigInt(params.id as string);
  const { address } = useAccount();

  const { data: project, isLoading: projectLoading } = useProjectDetails(projectId);
  const { data: loan, isLoading: loanLoading } = useProjectLoan(projectId);
  const { data: investorShares } = useInvestorShares(projectId, address);
  const { data: claimable } = useClaimableDividends(projectId, address);
  const { data: isInDefault } = useCheckDefaultStatus(projectId);
  const { data: equitySplit } = useEquitySplit(projectId);
  const { data: revenue } = useProjectRevenue(projectId);
  const { writeContract: declareDefault, isPending: isDeclaring } = useDeclareDefault();

  const handleDeclareDefault = () => {
    declareDefault({
      address: contracts.sepolia.loanManager,
      abi: LoanManagerABI,
      functionName: 'declareDefault',
      args: [projectId],
    });
  };

  if (projectLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center">
          <svg className="animate-spin h-8 w-8 text-green-500 mx-auto mb-3" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          <p className="text-slate-400">Loading project...</p>
        </div>
      </div>
    );
  }

  if (!project) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-16 text-center">
        <h2 className="text-2xl font-bold text-white mb-4">Project Not Found</h2>
        <Link href="/explore" className="text-green-400 hover:text-green-300">
          Back to Explore
        </Link>
      </div>
    );
  }

  const fundingPct =
    project.targetAmount > 0n
      ? Number((project.amountRaised * 100n) / project.targetAmount)
      : 0;

  const sharesAvailable = project.totalShares - project.sharesSold;
  const statusLabel = STATUS_LABELS[project.status] ?? 'Unknown';
  const statusColor = STATUS_COLORS[project.status] ?? STATUS_COLORS[0];
  type LoanResult = {
    monthlyPayment: bigint;
    termMonths: bigint;
    currentMonth: bigint;
    nextPaymentDue: bigint;
    totalPaid: bigint;
    totalOwed: bigint;
    isDefaulted: boolean;
    isCompleted: boolean;
    initialized: boolean;
  };

  const loanData = loan ? (loan as unknown as LoanResult) : undefined;
  const isActiveLoan = loanData?.initialized;

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-slate-500 mb-6">
        <Link href="/explore" className="hover:text-white transition-colors">Explore</Link>
        <span>/</span>
        <span className="text-white">Project #{projectId.toString()}</span>
      </div>

      {/* Title Row */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Solar Project #{projectId.toString()}</h1>
          <p className="text-slate-500 text-sm mt-1 font-mono">
            Host: {project.host}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className={`text-sm font-medium px-3 py-1.5 rounded-full border ${statusColor}`}>
            {statusLabel}
          </span>
          {isInDefault && (
            <button
              onClick={handleDeclareDefault}
              disabled={isDeclaring}
              className="bg-red-600 hover:bg-red-500 disabled:opacity-50 text-white text-sm font-medium px-3 py-1.5 rounded-lg transition-colors"
            >
              {isDeclaring ? 'Declaring...' : 'Declare Default'}
            </button>
          )}
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-6">
        {/* Left Column - Main Info */}
        <div className="lg:col-span-2 space-y-6">
          {/* Funding Progress */}
          <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
            <h2 className="text-white font-semibold text-lg mb-4">Funding Progress</h2>
            <div className="flex justify-between text-sm text-slate-400 mb-2">
              <span>{formatUSDC(project.amountRaised)} USDC raised</span>
              <span className="text-white font-semibold">{fundingPct}%</span>
            </div>
            <div className="h-3 bg-slate-700 rounded-full overflow-hidden mb-1">
              <div
                className="h-full bg-gradient-to-r from-green-500 to-emerald-400 rounded-full transition-all"
                style={{ width: `${Math.min(fundingPct, 100)}%` }}
              />
            </div>
            <p className="text-slate-500 text-xs mt-2">
              Target: {formatUSDC(project.targetAmount)} USDC
            </p>
          </div>

          {/* Project Details */}
          <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
            <h2 className="text-white font-semibold text-lg mb-4">Project Details</h2>
            <div className="grid sm:grid-cols-2 gap-4">
              {[
                { label: 'Target Amount', value: `$${formatUSDC(project.targetAmount)}` },
                { label: 'Amount Raised', value: `$${formatUSDC(project.amountRaised)}` },
                { label: 'Price per Share', value: `$${formatUSDC(project.pricePerShare)}` },
                { label: 'Total Shares', value: project.totalShares.toString() },
                { label: 'Shares Sold', value: project.sharesSold.toString() },
                { label: 'Shares Available', value: sharesAvailable.toString() },
                { label: 'Loan Term', value: `${project.termMonths} months` },
                { label: 'Start Date', value: project.isFunded ? formatDate(project.startDate) : 'Not started' },
              ].map((item) => (
                <div key={item.label} className="flex justify-between py-2 border-b border-slate-700/50 last:border-0">
                  <span className="text-slate-400 text-sm">{item.label}</span>
                  <span className="text-white text-sm font-medium">{item.value}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Loan Details */}
          {isActiveLoan && loanData && (
            <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
              <h2 className="text-white font-semibold text-lg mb-4">Loan Status</h2>
              <div className="grid sm:grid-cols-2 gap-4">
                {[
                  { label: 'Monthly Payment', value: `$${formatUSDC(loanData.monthlyPayment)}` },
                  { label: 'Total Owed', value: `$${formatUSDC(loanData.totalOwed)}` },
                  { label: 'Total Paid', value: `$${formatUSDC(loanData.totalPaid)}` },
                  { label: 'Current Month', value: `${loanData.currentMonth} / ${loanData.termMonths}` },
                  { label: 'Next Payment Due', value: formatDate(loanData.nextPaymentDue) },
                  { label: 'Status', value: loanData.isCompleted ? 'Completed' : loanData.isDefaulted ? 'Defaulted' : 'Active' },
                ].map((item) => (
                  <div key={item.label} className="flex justify-between py-2 border-b border-slate-700/50 last:border-0">
                    <span className="text-slate-400 text-sm">{item.label}</span>
                    <span className="text-white text-sm font-medium">{item.value}</span>
                  </div>
                ))}
              </div>

              {equitySplit && (() => {
                const [hostPct, investorPct] = equitySplit as unknown as [bigint, bigint];
                return (
                  <div className="mt-4 p-4 bg-slate-900/60 rounded-xl">
                    <p className="text-slate-400 text-sm mb-2">Current Equity Split (Amortization)</p>
                    <div className="flex gap-4">
                      <div>
                        <p className="text-2xl font-bold text-green-400">{investorPct.toString()}%</p>
                        <p className="text-slate-500 text-xs">Investors</p>
                      </div>
                      <div className="w-px bg-slate-700" />
                      <div>
                        <p className="text-2xl font-bold text-white">{hostPct.toString()}%</p>
                        <p className="text-slate-500 text-xs">Host</p>
                      </div>
                    </div>
                  </div>
                );
              })()}
            </div>
          )}

          {/* Revenue Pool */}
          {revenue && (() => {
            type RevPool = { totalRevenue: bigint; dividendPool: bigint; maintenanceReserve: bigint; insurancePool: bigint };
            const rev = revenue as unknown as RevPool;
            return (
              <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6">
                <h2 className="text-white font-semibold text-lg mb-4">Revenue Pool</h2>
                <div className="grid sm:grid-cols-3 gap-4">
                  {[
                    { label: 'Dividend Pool (93%)', value: `$${formatUSDC(rev.dividendPool)}`, color: 'text-green-400' },
                    { label: 'Maintenance (5%)', value: `$${formatUSDC(rev.maintenanceReserve)}`, color: 'text-yellow-400' },
                    { label: 'Insurance (2%)', value: `$${formatUSDC(rev.insurancePool)}`, color: 'text-blue-400' },
                  ].map((item) => (
                    <div key={item.label} className="bg-slate-900/60 rounded-xl p-3 text-center">
                      <p className={`text-xl font-bold ${item.color}`}>{item.value}</p>
                      <p className="text-slate-500 text-xs mt-1">{item.label}</p>
                    </div>
                  ))}
                </div>
              </div>
            );
          })()}
        </div>

        {/* Right Column - Actions */}
        <div className="space-y-4">
          {/* Your Position */}
          {address && investorShares !== undefined && investorShares > 0n && (
            <div className="bg-slate-800/60 border border-green-500/20 rounded-2xl p-5">
              <h3 className="text-white font-semibold mb-3">Your Position</h3>
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Shares Held</span>
                  <span className="text-white font-semibold">{investorShares.toString()}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-slate-400">Ownership</span>
                  <span className="text-green-400 font-semibold">
                    {project.totalShares > 0n
                      ? ((Number(investorShares) / Number(project.totalShares)) * 100).toFixed(2)
                      : '0'}%
                  </span>
                </div>
                {claimable !== undefined && claimable > 0n && (
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Claimable</span>
                    <span className="text-green-400 font-semibold">${formatUSDC(claimable)}</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Invest Widget - only show when in Funding status */}
          {project.status === 0 && sharesAvailable > 0n && (
            <InvestWidget
              projectId={projectId}
              pricePerShare={project.pricePerShare}
              sharesAvailable={sharesAvailable}
            />
          )}

          {/* Claim Dividends - show when Active */}
          {project.status === 1 && (
            <ClaimDividends projectId={projectId} />
          )}

          {/* Waterfall info */}
          <div className="bg-slate-800/40 border border-slate-700/30 rounded-xl p-4 text-xs text-slate-500">
            <p className="font-medium text-slate-400 mb-1">Revenue Distribution</p>
            <p>93% dividends / 5% maintenance / 2% insurance</p>
            <p className="mt-1">Pull-based — claim anytime, gas O(1)</p>
          </div>
        </div>
      </div>
    </div>
  );
}
