// 1. 引入 Foundry 部署记录
// 注意：如果路径报错，请检查 ../ 的数量（通常前端在 /frontend，JSON 在 /backend）
import deployment from "../../../backend/broadcast/Deploy.s.sol/31337/run-latest.json";

/**
 * 自动从 Foundry JSON 中提取合约地址的辅助函数
 */
const getAddr = (name: string, fallback: string): `0x${string}` => {
  const record = deployment.transactions.find(
    (tx) => tx.contractName === name && tx.transactionType === "CREATE"
  );
  return (record?.contractAddress || fallback) as `0x${string}`;
};

export const contracts = {
  localhost: {
    // 这些是自动抓取的（填入你 .sol 文件里的精确类名）
    solarProject: getAddr("SolarProject", "0x3Aa5ebB10DC797CAC828524e59A333d0A371443c"),
    loanManager: getAddr("LoanManager", "0xc6e7DF5E7b4f2A278906862b61205850344D4e7d"),
    revenueDistributor: getAddr("RevenueDistributor", "0x59b670e9fA9D0A427751Af201D676719a970857b"),
    maintenanceDAO: getAddr("MaintenanceDAO", "0x7a2088a1bFc9d81c55368AE168C2C02570cB814F"),
    
    // 这些通常是 Mock 或外部合约，如果不在 Deploy 脚本里创建，就保留手动地址
    mockUSDC: getAddr("MockUSDC", "0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE"),
    hostReputation: getAddr("HostReputation", "0x68B1D87F95878fE05B998F19b66F4baba5De1aed"),
    mockGridOracle: getAddr("MockGridOracle", "0xc5a5C42992dECbae36851359345FE25997F5C42d"),
    mockKeeper: getAddr("MockKeeper", "0x67d269191c92Caf3cD7723F116c85e6E9bf55933"),
  }
} as const;