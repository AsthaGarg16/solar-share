'use client';

import { useReadContract, useWriteContract, useAccount } from 'wagmi';
import { contracts } from '@/contracts/addresses';
import { SolarProjectABI } from '@/contracts/abis/SolarProjectABI';
import { LoanManagerABI } from '@/contracts/abis/LoanManagerABI';
import { RevenueDistributorABI } from '@/contracts/abis/RevenueDistributorABI';
import { HostReputationABI } from '@/contracts/abis/HostReputationABI';
import { MockUSDABI } from '@/contracts/abis/MockUSDABI';

const addr = contracts.sepolia;

// ─── SolarProject ───────────────────────────────────────────────────────────

export function useProjectCount() {
  return useReadContract({
    address: addr.solarProject,
    abi: SolarProjectABI,
    functionName: 'projectCount',
  });
}

export function useProjectDetails(projectId: bigint) {
  return useReadContract({
    address: addr.solarProject,
    abi: SolarProjectABI,
    functionName: 'getProjectDetails',
    args: [projectId],
    query: { enabled: projectId > 0n },
  });
}

export function useInvestorShares(projectId: bigint, investor: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.solarProject,
    abi: SolarProjectABI,
    functionName: 'getInvestorShares',
    args: [projectId, investor as `0x${string}`],
    query: { enabled: projectId > 0n && !!investor },
  });
}

export function useInitializeProject() {
  return useWriteContract();
}

export function useFundProject() {
  return useWriteContract();
}

export function useTriggerBuyout() {
  return useWriteContract();
}

// ─── LoanManager ─────────────────────────────────────────────────────────────

export function useProjectLoan(projectId: bigint) {
  return useReadContract({
    address: addr.loanManager,
    abi: LoanManagerABI,
    functionName: 'projectLoans',
    args: [projectId],
    query: { enabled: projectId > 0n },
  });
}

export function useCheckDefaultStatus(projectId: bigint) {
  return useReadContract({
    address: addr.loanManager,
    abi: LoanManagerABI,
    functionName: 'checkDefaultStatus',
    args: [projectId],
    query: { enabled: projectId > 0n },
  });
}

export function useEquitySplit(projectId: bigint) {
  return useReadContract({
    address: addr.loanManager,
    abi: LoanManagerABI,
    functionName: 'calculateEquitySplit',
    args: [projectId],
    query: { enabled: projectId > 0n },
  });
}

export function useInitializeLoan() {
  return useWriteContract();
}

export function usePayMonthlyInstallment() {
  return useWriteContract();
}

export function useDeclareDefault() {
  return useWriteContract();
}

// ─── RevenueDistributor ───────────────────────────────────────────────────────

export function useClaimableDividends(projectId: bigint, investor: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.revenueDistributor,
    abi: RevenueDistributorABI,
    functionName: 'getClaimableDividends',
    args: [projectId, investor as `0x${string}`],
    query: { enabled: projectId > 0n && !!investor },
  });
}

export function useProjectRevenue(projectId: bigint) {
  return useReadContract({
    address: addr.revenueDistributor,
    abi: RevenueDistributorABI,
    functionName: 'projectRevenue',
    args: [projectId],
    query: { enabled: projectId > 0n },
  });
}

export function useClaimDividends() {
  return useWriteContract();
}

export function useExecuteWaterfall() {
  return useWriteContract();
}

// ─── HostReputation ───────────────────────────────────────────────────────────

export function useHostScore(host: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.hostReputation,
    abi: HostReputationABI,
    functionName: 'getScore',
    args: [host as `0x${string}`],
    query: { enabled: !!host },
  });
}

export function useHostReputationDetails(host: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.hostReputation,
    abi: HostReputationABI,
    functionName: 'getReputationDetails',
    args: [host as `0x${string}`],
    query: { enabled: !!host },
  });
}

export function useHostTokenId(host: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.hostReputation,
    abi: HostReputationABI,
    functionName: 'hostToTokenId',
    args: [host as `0x${string}`],
    query: { enabled: !!host },
  });
}

export function useMintSBT() {
  return useWriteContract();
}

// ─── MockUSDC ────────────────────────────────────────────────────────────────

export function useUSDCBalance(account: `0x${string}` | undefined) {
  return useReadContract({
    address: addr.mockUSDC,
    abi: MockUSDABI,
    functionName: 'balanceOf',
    args: [account as `0x${string}`],
    query: { enabled: !!account },
  });
}

export function useUSDCAllowance(owner: `0x${string}` | undefined, spender: `0x${string}`) {
  return useReadContract({
    address: addr.mockUSDC,
    abi: MockUSDABI,
    functionName: 'allowance',
    args: [owner as `0x${string}`, spender],
    query: { enabled: !!owner },
  });
}

export function useMintUSDC() {
  return useWriteContract();
}

export function useApproveUSDC() {
  return useWriteContract();
}
