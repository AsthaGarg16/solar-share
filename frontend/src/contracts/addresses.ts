export const contracts = {
  sepolia: {
    mockUSDC: (process.env.NEXT_PUBLIC_MOCK_USDC || '0x0000000000000000000000000000000000000001') as `0x${string}`,
    solarProject: (process.env.NEXT_PUBLIC_SOLAR_PROJECT || '0x0000000000000000000000000000000000000002') as `0x${string}`,
    loanManager: (process.env.NEXT_PUBLIC_LOAN_MANAGER || '0x0000000000000000000000000000000000000003') as `0x${string}`,
    revenueDistributor: (process.env.NEXT_PUBLIC_REVENUE_DISTRIBUTOR || '0x0000000000000000000000000000000000000004') as `0x${string}`,
    hostReputation: (process.env.NEXT_PUBLIC_HOST_REPUTATION || '0x0000000000000000000000000000000000000005') as `0x${string}`,
    maintenanceDAO: (process.env.NEXT_PUBLIC_MAINTENANCE_DAO || '0x0000000000000000000000000000000000000006') as `0x${string}`,
  },
} as const;
