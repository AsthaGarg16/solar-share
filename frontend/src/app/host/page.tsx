"use client";

import { useState, useEffect, useCallback } from "react";
import { useAccount } from "wagmi";
import { useReadContract } from "wagmi";
import Link from "next/link";
import { parseUnits } from "viem";
import { contracts } from "@/contracts/addresses";
import { SolarProjectABI } from "@/contracts/abis/SolarProjectABI";
import { LoanManagerABI } from "@/contracts/abis/LoanManagerABI";
import { HostReputationABI } from "@/contracts/abis/HostReputationABI";
import { MockUSDABI } from "@/contracts/abis/MockUSDABI";
import {
  useHostReputationDetails,
  useHostTokenId,
  useMintSBT,
  useInitializeProject,
  useProjectCount,
  useWithdrawFunds,
  usePayMonthlyInstallment,
  useApproveUSDC,
} from "@/hooks/useContracts";
import { MintButton } from "@/components/MintButton";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";

const currentContracts = contracts.localhost;

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
  fundsWithdrawn: boolean;
  status: number;
};

type LoanData = {
  projectId: bigint;
  monthlyPayment: bigint;
  termMonths: bigint;
  currentMonth: bigint;
  lastPaymentDate: bigint;
  nextPaymentDue: bigint;
  totalPaid: bigint;
  totalOwed: bigint;
  isDefaulted: boolean;
  isCompleted: boolean;
  initialized: boolean;
};

function HostProjectLoader({
  projectId,
  address,
  onLoaded,
}: {
  projectId: bigint;
  address: string;
  onLoaded: (id: bigint, project: ProjectData, loan: LoanData | null) => void;
}) {
  const { data: project } = useReadContract({
    address: currentContracts.solarProject,
    abi: SolarProjectABI,
    functionName: "getProjectDetails",
    args: [projectId],
  });

  const { data: loan, error: loanError } = useReadContract({
    address: currentContracts.loanManager,
    abi: LoanManagerABI,
    functionName: "projectLoans",
    args: [projectId],
    query: { refetchInterval: 3000 },
  });

  useEffect(() => {
    if (project && (project as ProjectData).host.toLowerCase() === address.toLowerCase()) {
      const pData = project as ProjectData;

      // onLoaded(projectId, project as ProjectData, loanTyped?.initialized ? loanTyped : null);
      onLoaded(
        projectId,
        project as ProjectData,
        (loan as any)?.[10] // 检查索引 10 是否为 true
          ? {
              projectId: (loan as any)[0],
              monthlyPayment: (loan as any)[1],
              termMonths: (loan as any)[2],
              currentMonth: (loan as any)[3],
              lastPaymentDate: (loan as any)[4],
              nextPaymentDue: (loan as any)[5],
              totalPaid: (loan as any)[6],
              totalOwed: (loan as any)[7],
              isDefaulted: (loan as any)[8],
              isCompleted: (loan as any)[9],
              initialized: (loan as any)[10],
            }
          : null
      );
    }
  }, [project, loan, projectId, address, onLoaded]);

  return null;
}

const STATUS_LABELS: Record<number, string> = {
  0: "Funding",
  1: "Active",
  2: "Defaulted",
  3: "Bought Out",
};

const STATUS_COLORS: Record<number, string> = {
  0: "text-yellow-400",
  1: "text-green-400",
  2: "text-red-400",
  3: "text-slate-400",
};

function formatUSDC(amount: bigint): string {
  return (Number(amount) / 1e6).toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatDate(ts: bigint): string {
  if (ts === 0n) return "—";
  return new Date(Number(ts) * 1000).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default function HostPage() {
  const { address, isConnected } = useAccount();
  const [tab, setTab] = useState<"overview" | "create" | "manage">("overview");
  const [hostProjects, setHostProjects] = useState<
    Map<string, { project: ProjectData; loan: LoanData | null }>
  >(new Map());

  // Create project form state
  const [targetAmount, setTargetAmount] = useState("");
  const [termMonths, setTermMonths] = useState("");
  const [totalShares, setTotalShares] = useState("");

  // Pay installment form state
  const [payProjectId, setPayProjectId] = useState("");

  const {
    data: repDetails,
    refetch: refetchRep,
    error: readError, // 👈 重点：捕捉错误
    status: readStatus, // 👈 重点：查看状态（是 'error' 还是 'pending'）
  } = useHostReputationDetails(address);

  useEffect(() => {
    if (repDetails) {
      console.log("Raw Data from Contract:", repDetails);
    }
  }, [repDetails]);

  // 紧接着下面写打印
  const { data: tokenId } = useHostTokenId(address);
  const { data: projectCount } = useProjectCount();

  const { writeContract: mintSBT, isPending: isMinting } = useMintSBT();
  const { writeContract: createProject, isPending: isCreating } = useInitializeProject();
  const { writeContract: withdrawFunds, isPending: isWithdrawing } = useWithdrawFunds();
  const { writeContract: approve, isPending: isApproving } = useApproveUSDC();
  const { writeContract: payInstallment, isPending: isPaying } = usePayMonthlyInstallment();

  const count = projectCount ? Number(projectCount) : 0;
  const projectIds = Array.from({ length: count }, (_, i) => BigInt(i + 1));

  const handleProjectLoaded = useCallback(
    (id: bigint, project: ProjectData, loan: LoanData | null) => {
      setHostProjects((prev) => {
        const next = new Map(prev);
        next.set(id.toString(), { project, loan });
        return next;
      });
    },
    []
  );

  const repData = repDetails as
    | {
        score: bigint;
        projectsCreated: bigint;
        projectsCompleted: bigint;
        projectsDefaulted: bigint;
        totalSlashed: bigint;
        exists: boolean;
      }
    | undefined;
  console.log("Full repData Object:", repData);

  const hasSBT = repData?.exists ?? false;
  const scoreNum = hasSBT ? Number(repData!.score) : 0;
  const scoreColor =
    scoreNum >= 800 ? "text-green-400" : scoreNum >= 500 ? "text-yellow-400" : "text-red-400";

  const handleMintSBT = () => {
    if (!address) return;
    // mintSBT({
    //   address: currentContracts.hostReputation,
    //   abi: HostReputationABI,
    //   functionName: 'mintSBT',
    //   args: [address],
    // });
    mintSBT(
      {
        address: currentContracts.hostReputation,
        abi: HostReputationABI,
        functionName: "mintSBT",
        args: [address],
      },
      {
        // 👈 重点：添加这个 onSuccess 回调
        onSuccess: () => {
          refetchRep(); // 这里的名字要和上面解构出来的名字一致
        },
        onError: (error) => {
          console.error("Mint 失败:", error);
        },
      }
    );
  };

  const { writeContract: submitTransaction, data: hash, isPending } = useWriteContract();
  const { isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  });

  useEffect(() => {
    if (isConfirmed) {
      console.log("Transaction confirmed! Reloading...");
      window.location.reload();
    }
  }, [isConfirmed]);

  const handleCreateProject = () => {
    if (!targetAmount || !termMonths || !totalShares) return;
    const target = parseUnits(targetAmount, 6);
    const projectName = "My Solar Project";
    submitTransaction({
      address: currentContracts.solarProject,
      abi: SolarProjectABI,
      functionName: "initializeProject",
      args: [projectName, target, BigInt(termMonths), BigInt(totalShares)],
    });
  };

  const handleWithdrawFunds = (projectId: bigint) => {
    withdrawFunds({
      address: currentContracts.solarProject,
      abi: SolarProjectABI,
      functionName: "withdrawFunds",
      args: [projectId],
    });
  };

  const handleApproveAndPay = (projectId: bigint, amount: bigint) => {
    approve(
      {
        address: currentContracts.mockUSDC,
        abi: MockUSDABI,
        functionName: "approve",
        args: [currentContracts.loanManager, amount],
      },
      {
        onSuccess: () => {
          setTimeout(() => {
            payInstallment({
              address: currentContracts.loanManager,
              abi: LoanManagerABI,
              functionName: "payMonthlyInstallment",
              args: [projectId],
            });
          }, 2000);
        },
      }
    );
  };

  const hostProjectList = Array.from(hostProjects.values());

  if (!isConnected) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-24 text-center">
        <h1 className="text-2xl font-bold text-white mb-3">Connect Your Wallet</h1>
        <p className="text-slate-400">Connect your wallet to access the host dashboard.</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Load all projects to find host's */}
      {address &&
        projectIds.map((id) => (
          <HostProjectLoader
            key={id.toString()}
            projectId={id}
            address={address}
            onLoaded={handleProjectLoaded}
          />
        ))}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Host Dashboard</h1>
          <p className="text-slate-500 text-sm mt-1 font-mono">
            {address?.slice(0, 6)}...{address?.slice(-4)}
          </p>
        </div>
        <MintButton />
      </div>

      {/* Reputation Card */}
      <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 mb-8">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h2 className="text-white font-semibold text-lg mb-1">Reputation Score</h2>
            <p className="text-slate-500 text-sm">
              {hasSBT ? `Token #${tokenId?.toString()} — Soulbound` : "No reputation token yet"}
            </p>
          </div>

          {hasSBT ? (
            <div className="text-center sm:text-right">
              <p className={`text-5xl font-bold ${scoreColor}`}>{scoreNum}</p>
              <p className="text-slate-500 text-xs mt-1">/ 1000 max</p>
            </div>
          ) : (
            <button
              onClick={handleMintSBT}
              disabled={isMinting}
              className="bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white font-medium py-2.5 px-6 rounded-xl transition-colors"
            >
              {isMinting ? "Minting..." : "Mint Reputation Token"}
            </button>
          )}
        </div>

        {hasSBT && repData && (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-5">
            {[
              { label: "Created", value: repData.projectsCreated.toString() },
              { label: "Completed", value: repData.projectsCompleted.toString() },
              { label: "Defaulted", value: repData.projectsDefaulted.toString() },
              { label: "Total Slashed", value: repData.totalSlashed.toString() },
            ].map((item) => (
              <div key={item.label} className="bg-slate-900/60 rounded-xl p-3 text-center">
                <p className="text-white font-bold text-xl">{item.value}</p>
                <p className="text-slate-500 text-xs mt-0.5">{item.label}</p>
              </div>
            ))}
          </div>
        )}

        {/* Score bar */}
        {hasSBT && (
          <div className="mt-4">
            <div className="h-2 bg-slate-700 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full transition-all ${
                  scoreNum >= 800
                    ? "bg-green-500"
                    : scoreNum >= 500
                      ? "bg-yellow-500"
                      : "bg-red-500"
                }`}
                style={{ width: `${scoreNum / 10}%` }}
              />
            </div>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-slate-800/40 p-1 rounded-xl w-fit">
        {(["overview", "create", "manage"] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors capitalize ${
              tab === t ? "bg-slate-700 text-white" : "text-slate-400 hover:text-white"
            }`}
          >
            {t === "create" ? "Create Project" : t === "manage" ? "Manage Loans" : "My Projects"}
          </button>
        ))}
      </div>

      {/* Tab: Overview */}
      {tab === "overview" && (
        <div>
          {hostProjectList.length === 0 ? (
            <div className="text-center py-16">
              <p className="text-slate-400 mb-4">You haven{"'"}t created any projects yet.</p>
              <button
                onClick={() => setTab("create")}
                className="bg-green-600 hover:bg-green-500 text-white font-medium py-2.5 px-6 rounded-xl transition-colors"
              >
                Create Your First Project
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              {hostProjectList.map(({ project, loan }) => (
                <div
                  key={project.projectId.toString()}
                  className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-5"
                >
                  <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-white font-semibold">
                          Project #{project.projectId.toString()}
                        </h3>
                        <span className={`text-xs font-medium ${STATUS_COLORS[project.status]}`}>
                          {STATUS_LABELS[project.status]}
                        </span>
                      </div>
                      <div className="flex flex-wrap gap-4 text-sm text-slate-400">
                        <span>
                          Target:{" "}
                          <span className="text-white">${formatUSDC(project.targetAmount)}</span>
                        </span>
                        <span>
                          Raised:{" "}
                          <span className="text-white">${formatUSDC(project.amountRaised)}</span>
                        </span>
                        <span>
                          Term:{" "}
                          <span className="text-white">{project.termMonths.toString()}mo</span>
                        </span>
                        {loan && (
                          <>
                            <span>
                              Month:{" "}
                              <span className="text-white">
                                {loan.currentMonth.toString()}/{loan.termMonths.toString()}
                              </span>
                            </span>
                            <span>
                              Next Due:{" "}
                              <span className="text-white">{formatDate(loan.nextPaymentDue)}</span>
                            </span>
                          </>
                        )}
                      </div>
                    </div>

                    <div className="flex gap-2 flex-wrap">
                      <Link
                        href={`/projects/${project.projectId}`}
                        className="bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
                      >
                        View
                      </Link>
                      {/* Show Withdraw button when funded but funds not yet withdrawn */}
                      {project.isFunded && !project.fundsWithdrawn && !loan && (
                        <button
                          onClick={() => handleWithdrawFunds(project.projectId)}
                          disabled={isWithdrawing}
                          className="bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
                        >
                          {isWithdrawing ? "Withdrawing..." : "Withdraw Funds & Start Loan"}
                        </button>
                      )}
                      {loan && !loan.isCompleted && !loan.isDefaulted && (
                        <button
                          onClick={() =>
                            handleApproveAndPay(project.projectId, loan.monthlyPayment)
                          }
                          disabled={isApproving || isPaying}
                          className="bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
                        >
                          {isApproving
                            ? "Approving..."
                            : isPaying
                              ? "Paying..."
                              : `Pay $${formatUSDC(loan.monthlyPayment)}`}
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Tab: Create Project */}
      {tab === "create" && (
        <div className="max-w-lg">
          {!hasSBT && (
            <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-xl p-4 mb-6 flex items-start gap-3">
              <svg
                className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
              <p className="text-yellow-300 text-sm">
                You need to mint your Reputation Token before creating a project.{" "}
                <button onClick={handleMintSBT} className="underline hover:no-underline">
                  Mint it here.
                </button>
              </p>
            </div>
          )}

          <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 space-y-5">
            <h2 className="text-white font-semibold text-lg">New Solar Project</h2>

            <div>
              <label className="text-slate-400 text-sm mb-1.5 block">Target Amount (USDC)</label>
              <input
                type="number"
                value={targetAmount}
                onChange={(e) => setTargetAmount(e.target.value)}
                placeholder="e.g. 20000"
                className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 transition-colors"
              />
              <p className="text-slate-600 text-xs mt-1">In USDC (e.g. 20000 = $20,000)</p>
            </div>

            <div>
              <label className="text-slate-400 text-sm mb-1.5 block">Loan Term (Months)</label>
              <input
                type="number"
                value={termMonths}
                onChange={(e) => setTermMonths(e.target.value)}
                placeholder="120"
                className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 transition-colors"
              />
            </div>

            <div>
              <label className="text-slate-400 text-sm mb-1.5 block">Total Shares to Issue</label>
              <input
                type="number"
                value={totalShares}
                onChange={(e) => setTotalShares(e.target.value)}
                placeholder="1000"
                className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 transition-colors"
              />
            </div>

            {targetAmount && totalShares && (
              <div className="bg-green-500/10 border border-green-500/20 rounded-xl p-3 text-sm">
                <div className="flex justify-between text-slate-400">
                  <span>Price per Share</span>
                  <span className="text-white">
                    $
                    {(Number(targetAmount) / Number(totalShares)).toLocaleString("en-US", {
                      minimumFractionDigits: 2,
                      maximumFractionDigits: 2,
                    })}
                  </span>
                </div>
              </div>
            )}

            <button
              onClick={handleCreateProject}
              disabled={
                isPending ||
                !!hash ||
                isCreating ||
                !hasSBT ||
                !targetAmount ||
                !termMonths ||
                !totalShares
              }
              className="w-full bg-green-600 hover:bg-green-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold py-3 px-4 rounded-xl transition-colors"
            >
              {isCreating ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                    <circle
                      className="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      strokeWidth="4"
                    />
                    <path
                      className="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                    />
                  </svg>
                  Creating...
                </span>
              ) : (
                "Create Project"
              )}
            </button>
          </div>
        </div>
      )}

      {/* Tab: Manage Loans */}
      {tab === "manage" && (
        <div className="max-w-lg space-y-6">
          {/* Withdraw & Start Loan notice */}
          <div className="bg-blue-500/10 border border-blue-500/20 rounded-2xl p-5">
            <div className="flex items-start gap-3">
              <svg
                className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <div>
                <p className="text-blue-300 text-sm font-medium mb-1">Loan starts automatically</p>
                <p className="text-slate-400 text-sm">
                  Once your project is fully funded, go to{" "}
                  <button
                    onClick={() => setTab("overview")}
                    className="text-blue-400 underline hover:no-underline"
                  >
                    My Projects
                  </button>{" "}
                  and click <strong className="text-white">Withdraw Funds &amp; Start Loan</strong>.
                  Your raised capital is sent to you and the first payment becomes due 30 days
                  later.
                </p>
              </div>
            </div>
          </div>

          {/* Pay Installment */}
          <div className="bg-slate-800/60 border border-slate-700/50 rounded-2xl p-6 space-y-4">
            <h2 className="text-white font-semibold text-lg">Pay Monthly Installment</h2>
            <p className="text-slate-400 text-sm">
              Make your monthly loan payment. USDC approval is handled automatically.
            </p>
            <div>
              <label className="text-slate-400 text-sm mb-1.5 block">Project ID</label>
              <input
                type="number"
                value={payProjectId}
                onChange={(e) => setPayProjectId(e.target.value)}
                placeholder="e.g. 1"
                className="w-full bg-slate-900/80 border border-slate-600 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:border-green-500/60 transition-colors"
              />
            </div>

            {hostProjectList
              .filter(({ loan }) => loan && !loan.isCompleted && !loan.isDefaulted)
              .map(({ project, loan }) => (
                <div
                  key={project.projectId.toString()}
                  className="flex items-center justify-between bg-slate-900/60 rounded-xl p-3"
                >
                  <div>
                    <p className="text-white text-sm font-medium">
                      Project #{project.projectId.toString()}
                    </p>
                    <p className="text-slate-500 text-xs">
                      Month {loan!.currentMonth.toString()}/{loan!.termMonths.toString()} — Due{" "}
                      {formatDate(loan!.nextPaymentDue)}
                    </p>
                  </div>
                  <button
                    onClick={() => handleApproveAndPay(project.projectId, loan!.monthlyPayment)}
                    disabled={isApproving || isPaying}
                    className="bg-green-600 hover:bg-green-500 disabled:opacity-50 text-white text-xs font-medium px-3 py-1.5 rounded-lg transition-colors"
                  >
                    Pay ${formatUSDC(loan!.monthlyPayment)}
                  </button>
                </div>
              ))}
          </div>
        </div>
      )}
    </div>
  );
}
