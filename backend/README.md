# SolarShare — Backend

Smart contracts for the SolarShare protocol, built with [Foundry](https://book.getfoundry.sh/).

---

## Project Structure

```
backend/
├── src/
│   ├── core/
│   │   ├── SolarProject.sol        # ERC-1155 fractional shares, capital formation, buyouts
│   │   ├── LoanManager.sol         # Payment tracking, default detection, equity splits
│   │   ├── RevenueDistributor.sol  # 93/5/2 revenue waterfall, pull-based dividends
│   │   ├── HostReputation.sol      # Soulbound ERC-721 credit score, slashing
│   │   └── MaintenanceDAO.sol      # Governance for the 5% maintenance reserve
│   ├── mocks/
│   │   ├── MockUSDC.sol            # 6-decimal stablecoin for local testing
│   │   ├── MockGridOracle.sol      # Simulates grid revenue ($20–$150/month)
│   │   └── MockChainlinkKeeper.sol # Automates default checks
│   └── interfaces/
│       ├── ISolarProject.sol
│       ├── ILoanManager.sol
│       ├── IRevenueDistributor.sol
│       └── IHostReputation.sol
├── test/
│   ├── unit/
│   │   ├── SolarProject.t.sol
│   │   ├── LoanManager.t.sol
│   │   ├── RevenueDistributor.t.sol
│   │   ├── HostReputation.t.sol
│   │   └── MaintenanceDAO.t.sol
│   ├── integration/
│   │   └── FullSystem.t.sol        # End-to-end lifecycle tests
│   └── Base.t.sol                  # Shared setup and helper functions
├── script/
│   └── Deploy.s.sol                # Deploys all contracts, writes deployments/31337.json
├── deployments/
│   └── 31337.json                  # Auto-generated contract addresses (read by frontend)
└── foundry.toml
```

---

## Prerequisites

Install Foundry (includes `forge`, `cast`, and `anvil`):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

## Setup

### 1. Install dependencies

```bash
cd backend
forge install
```

### 2. Build contracts

```bash
forge build
```

---

## Running Locally

### Step 1 — Start Anvil

Open a dedicated terminal and keep it running throughout your session:

```bash
anvil
```

Anvil starts a local blockchain at `http://127.0.0.1:8545` (chain ID `31337`) and prints 10 pre-funded test accounts with their private keys.

### Step 2 — Deploy contracts

In a separate terminal from the `backend/` directory:

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

This deploys all 8 contracts, wires them together, and writes their addresses to `deployments/31337.json`. The frontend reads this file automatically — no manual address copying needed.

---

## Anvil Test Accounts

These are Anvil's default deterministic accounts (same every time). Import them into MetaMask for UI testing.

| Role             | Address                                      | Private Key                                                          |
| ---------------- | -------------------------------------------- | -------------------------------------------------------------------- |
| Deployer / Owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Host             | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Investor 1       | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| Investor 2       | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| Investor 3       | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b` |

To add the Anvil network to MetaMask:

- **Network name:** `Anvil`
- **RPC URL:** `http://127.0.0.1:8545`
- **Chain ID:** `31337`
- **Currency symbol:** `ETH`

To import an account: MetaMask → account icon → **Import account** → paste the private key.

---

## Useful Cast Commands

### Mint test USDC to a wallet

```bash
cast send <MOCK_USDC_ADDRESS> "mint(address,uint256)" \
  <RECIPIENT_ADDRESS> 100000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Submit mock grid revenue (for project ID 1)

```bash
cast send <MOCK_GRID_ORACLE_ADDRESS> "submitGridRevenue(uint256)" 1 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Execute the revenue waterfall

```bash
cast send <REVENUE_DISTRIBUTOR_ADDRESS> "executeWaterfall(uint256)" 1 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Fast-forward time

```bash
# Advance by 7 days (e.g. to close a governance vote)
cast rpc anvil_increaseTime 604800 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545

# Advance by 31 days (e.g. to trigger a missed payment / default)
cast rpc anvil_increaseTime 2678400 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545
```

---

## Running Tests

```bash
# Run all tests
forge test

# Run with verbose output (shows logs and traces)
forge test -vvv

# Run a specific test file
forge test --match-path test/unit/SolarProject.t.sol

# Run a specific test by name
forge test --match-test test_FullLifecycle_HappyPath -vvv

# Coverage report
forge coverage
```
