# Local Development Guide — Backend (Anvil) + Frontend (Next.js)

This guide covers running the full Solar Share stack locally against a local Anvil network, using Chainnode as the RPC provider if connecting to Sepolia.

---

## Prerequisites

### 1. Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify:

```bash
forge --version
cast --version
anvil --version
```

### 2. Install Node.js dependencies (frontend)

```bash
cd solar-share/frontend
npm install
```

---

## Part 1: Run the Backend Locally

### Step 1: Start Anvil (local blockchain)

Open a dedicated terminal and keep it running throughout development:

```bash
cd solar-share/backend

anvil
```

Anvil starts a local chain at `http://127.0.0.1:8545` (chain ID `31337`).  
It prints 10 pre-funded test accounts with private keys — copy the first private key, you'll use it below.

> **Tip:** Add `--block-time 1` if you want auto-mining every second instead of on-demand:
>
> ```bash
> anvil --block-time 1
> ```

---

### Step 2: Set up the `.env` file

```bash
cd solar-share/backend
cp .env.example .env
```

Edit `.env` — replace **only** these two lines (leave everything else blank for now):

```env
# Point to your local Anvil instance
RPC_URL=http://127.0.0.1:8545

# Use the first private key printed by Anvil (it has 10,000 ETH)
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

> The private key above is Anvil's default account #0.

---

### Step 3: Build contracts

```bash
cd solar-share/backend
forge build
```

---

### Step 4: Deploy all contracts to Anvil

```bash
cd solar-share/backend
source .env

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vvvv
```

The script prints all deployed addresses. You'll see output like:

```
MockUSDC deployed: 0x5FbDB2315678afecb367f032d93F642f64180aa3
HostReputation deployed: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
SolarProject deployed: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
...
```

---

### Step 5: Update deployment addresses

The deploy script automatically writes addresses to `backend/deployments/31337.json`, which the frontend reads directly. Verify it was updated:

```bash
cat solar-share/backend/deployments/31337.json
```

It should look like:

```json
{
  "mockUSDC": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  "hostReputation": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  "solarProject": "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  "loanManager": "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
  "revenueDistributor": "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9",
  "maintenanceDAO": "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707",
  "mockGridOracle": "0x0165878A594ca255338adfa4d48449f69242Eb8F",
  "mockKeeper": "0xa513E6E4b8f2a923D98304ec87F64353C4D5C853"
}
```

> If the deploy script does not write this file automatically, copy the printed addresses manually into `backend/deployments/31337.json`.

---

### Step 6: Run the tests (optional but recommended)

```bash
cd solar-share/backend

# All tests
forge test

# With logs
forge test -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

---

## Part 2: Run the Frontend Locally

### Step 1: Configure the frontend environment

```bash
cd solar-share/frontend
cp .env.local.example .env.local
```

Edit `.env.local`:

```env
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=solar-share-demo
```

The frontend reads contract addresses from `backend/deployments/31337.json`

---

### Step 2: Start the frontend

```bash
cd solar-share/frontend
npm run dev
```

The app is available at `http://localhost:3000`.

---

### Step 3: Connect MetaMask to Anvil

1. Open MetaMask → **Add a network manually**:
   - Network name: `Anvil Local`
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
   - Currency symbol: `ETH`

2. Import an Anvil test account into MetaMask:
   - MetaMask → Import account → paste one of the private keys printed by Anvil
   - Each account starts with 10,000 ETH for gas

3. The frontend will auto-detect chain ID `31337` and load addresses from `31337.json`.

---

## Part 3: Manual Testing with `cast` (against local Anvil)

All commands below target your local Anvil. Load the env first:

```bash
cd solar-share/backend
source .env

export MY_ADDRESS=$(cast wallet address $PRIVATE_KEY)
echo $MY_ADDRESS

# Load contract addresses from deployment file
export MOCK_USDC=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mockUSDC'])")
export SOLAR_PROJECT=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['solarProject'])")
export LOAN_MANAGER=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['loanManager'])")
export REVENUE_DISTRIBUTOR=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['revenueDistributor'])")
export HOST_REPUTATION=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['hostReputation'])")
export MAINTENANCE_DAO=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['maintenanceDAO'])")
export MOCK_GRID_ORACLE=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mockGridOracle'])")
export MOCK_KEEPER=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mockKeeper'])")
```

---

### Step 1: Mint MockUSDC

```bash
# Mint 100,000 USDC to yourself (6 decimals = 100000 * 1e6)
cast send $MOCK_USDC "mint(address,uint256)" \
  $MY_ADDRESS 100000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Check balance
cast call $MOCK_USDC "balanceOf(address)" $MY_ADDRESS \
  --rpc-url http://127.0.0.1:8545 | cast --to-dec
```

---

### Step 2: Mint Soulbound Token (Host Reputation)

```bash
cast send $HOST_REPUTATION "mintSBT(address)" \
  $MY_ADDRESS \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Score should be 1000
cast call $HOST_REPUTATION "getScore(address)" $MY_ADDRESS \
  --rpc-url http://127.0.0.1:8545 | cast --to-dec
```

---

### Step 3: Create a Solar Project

```bash
# initializeProject(targetAmount, termMonths, totalShares)
# $20,000 target, 120 months, 1000 shares
cast send $SOLAR_PROJECT "initializeProject(uint256,uint256,uint256)" \
  20000000000 120 1000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Verify project count
cast call $SOLAR_PROJECT "projectCount()" \
  --rpc-url http://127.0.0.1:8545 | cast --to-dec
```

---

### Step 4: Fund the Project

```bash
# Price per share = $20 (20 * 1e6). Buying 1000 shares = $20,000
cast send $MOCK_USDC "approve(address,uint256)" \
  $SOLAR_PROJECT 20000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

cast send $SOLAR_PROJECT "fundProject(uint256,uint256)" \
  1 1000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Verify shares owned
cast call $SOLAR_PROJECT "getInvestorShares(uint256,address)" \
  1 $MY_ADDRESS --rpc-url http://127.0.0.1:8545 | cast --to-dec
```

---

### Step 5: Initialize the Loan

```bash
# initializeLoan(projectId, monthlyPayment, termMonths)
# $200/month = 200 * 1e6
cast send $LOAN_MANAGER "initializeLoan(uint256,uint256,uint256)" \
  1 200000000 120 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

---

### Step 6: Make Monthly Payment

```bash
cast send $MOCK_USDC "approve(address,uint256)" \
  $LOAN_MANAGER 200000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

cast send $LOAN_MANAGER "payMonthlyInstallment(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

---

### Step 7: Deposit Grid Revenue

```bash
# Mint USDC to the oracle so it can deposit
cast send $MOCK_USDC "mint(address,uint256)" \
  $MOCK_GRID_ORACLE 1000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Oracle deposits random revenue ($20–$150) for project 1
cast send $MOCK_GRID_ORACLE "submitGridRevenue(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

---

### Step 8: Execute Waterfall (93/5/2 Split)

```bash
cast send $REVENUE_DISTRIBUTOR "executeWaterfall(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Check revenue pool state
cast call $REVENUE_DISTRIBUTOR "projectRevenue(uint256)" 1 \
  --rpc-url http://127.0.0.1:8545
```

---

### Step 9: Claim Dividends

```bash
# Check claimable amount
cast call $REVENUE_DISTRIBUTOR "getClaimableDividends(uint256,address)" \
  1 $MY_ADDRESS --rpc-url http://127.0.0.1:8545 | cast --to-dec

# Claim
cast send $REVENUE_DISTRIBUTOR "claimDividends(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

---

### Step 10: Fast-Forward Time (Default / Governance Testing)

```bash
# Fast-forward 31 days (for default detection)
cast rpc anvil_increaseTime 2678400 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545

# Check if project is in default
cast call $LOAN_MANAGER "checkDefaultStatus(uint256)" 1 \
  --rpc-url http://127.0.0.1:8545

# Declare default
cast send $LOAN_MANAGER "declareDefault(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Check reputation (should be 800 after -200 slash)
cast call $HOST_REPUTATION "getScore(address)" $MY_ADDRESS \
  --rpc-url http://127.0.0.1:8545 | cast --to-dec

# Fast-forward 7 days (for governance voting period)
cast rpc anvil_increaseTime 604800 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545
```

---

### Governance (MaintenanceDAO)

```bash
# Submit proposal
# submitProposal(projectId, description, amount, vendor)
cast send $MAINTENANCE_DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Replace damaged inverter" 500000000 <VENDOR_ADDRESS> \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Vote YES
cast send $MAINTENANCE_DAO "castVote(uint256,bool)" \
  1 true \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Fast-forward past voting period (7 days)
cast rpc anvil_increaseTime 604800 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545

# Execute proposal
cast send $MAINTENANCE_DAO "executeProposal(uint256)" \
  1 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Verify vendor received funds
cast call $MOCK_USDC "balanceOf(address)" <VENDOR_ADDRESS> \
  --rpc-url http://127.0.0.1:8545 | cast --to-dec
```

---

### Buyout

```bash
# Approve + trigger buyout ($15,000 offer)
cast send $MOCK_USDC "approve(address,uint256)" \
  $SOLAR_PROJECT 15000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

cast send $SOLAR_PROJECT "triggerBuyout(uint256,uint256)" \
  1 15000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

---

### Useful Read Commands

```bash
RPC=http://127.0.0.1:8545

# Project state
cast call $SOLAR_PROJECT "getProjectDetails(uint256)" 1 --rpc-url $RPC

# Loan state
cast call $LOAN_MANAGER "projectLoans(uint256)" 1 --rpc-url $RPC

# Revenue pool
cast call $REVENUE_DISTRIBUTOR "projectRevenue(uint256)" 1 --rpc-url $RPC

# Host reputation
cast call $HOST_REPUTATION "getReputationDetails(address)" $MY_ADDRESS --rpc-url $RPC

# Default status
cast call $LOAN_MANAGER "checkDefaultStatus(uint256)" 1 --rpc-url $RPC | cast --to-dec

# Equity split
cast call $LOAN_MANAGER "calculateEquitySplit(uint256)" 1 --rpc-url $RPC

# ERC-1155 share balance
cast call $SOLAR_PROJECT "balanceOf(address,uint256)" $MY_ADDRESS 1 --rpc-url $RPC | cast --to-dec

# USDC balance
cast call $MOCK_USDC "balanceOf(address)" $MY_ADDRESS --rpc-url $RPC | cast --to-dec
```

---

## Quick Start (Full Flow)

Open **three terminals**:

**Terminal 1 — Anvil:**

```bash
cd solar-share/backend
anvil
```

**Terminal 2 — Deploy + interact:**

```bash
cd solar-share/backend
source .env
export MY_ADDRESS=$(cast wallet address $PRIVATE_KEY)
RPC=http://127.0.0.1:8545

# Deploy
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC --broadcast -vvvv

# Load addresses
export MOCK_USDC=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mockUSDC'])")
export SOLAR_PROJECT=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['solarProject'])")
export LOAN_MANAGER=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['loanManager'])")
export REVENUE_DISTRIBUTOR=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['revenueDistributor'])")
export HOST_REPUTATION=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['hostReputation'])")
export MOCK_GRID_ORACLE=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mockGridOracle'])")
export MAINTENANCE_DAO=$(cat deployments/31337.json | python3 -c "import sys,json; print(json.load(sys.stdin)['maintenanceDAO'])")

# Full demo flow
cast send $MOCK_USDC "mint(address,uint256)" $MY_ADDRESS 100000000000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $HOST_REPUTATION "mintSBT(address)" $MY_ADDRESS --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $SOLAR_PROJECT "initializeProject(uint256,uint256,uint256)" 20000000000 120 1000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $MOCK_USDC "approve(address,uint256)" $SOLAR_PROJECT 20000000000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $SOLAR_PROJECT "fundProject(uint256,uint256)" 1 1000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $LOAN_MANAGER "initializeLoan(uint256,uint256,uint256)" 1 200000000 120 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $MOCK_USDC "approve(address,uint256)" $LOAN_MANAGER 200000000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $LOAN_MANAGER "payMonthlyInstallment(uint256)" 1 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $MOCK_USDC "mint(address,uint256)" $MOCK_GRID_ORACLE 1000000000 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $MOCK_GRID_ORACLE "submitGridRevenue(uint256)" 1 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $REVENUE_DISTRIBUTOR "executeWaterfall(uint256)" 1 --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $REVENUE_DISTRIBUTOR "getClaimableDividends(uint256,address)" 1 $MY_ADDRESS --rpc-url $RPC | cast --to-dec
cast send $REVENUE_DISTRIBUTOR "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $PRIVATE_KEY

echo "Done! Local deployment complete."
```

**Terminal 3 — Frontend:**

```bash
cd solar-share/frontend
npm run dev
# Open http://localhost:3000
```

---

## Connecting to Sepolia via Chainnode (Optional)

If you want to deploy to Sepolia instead of running locally, use your Chainnode RPC endpoint:

### Get your Chainnode RPC URL

1. Log in to [Chainnode](https://www.chainnode.com)
2. Create or select an app → choose **Ethereum Sepolia**
3. Copy the HTTPS endpoint — it will look like:
   ```
   https://sepolia.chainnode.io/v1/YOUR_API_KEY
   ```

### Update `.env`

```env
SEPOLIA_RPC_URL=https://sepolia.chainnode.io/v1/YOUR_API_KEY
PRIVATE_KEY=your_test_wallet_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Deploy to Sepolia

```bash
cd solar-share/backend
source .env

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Update frontend for Sepolia

In [frontend/src/config/wagmi.ts](frontend/src/config/wagmi.ts), add `sepolia` to the chains list and update [frontend/src/contracts/addresses.ts](frontend/src/contracts/addresses.ts) to import from a `11155111.json` deployment file (or hardcode addresses from the deploy output).

> **Note:** You need Sepolia ETH for gas. Get it from https://sepoliafaucet.com or https://faucets.chain.link/sepolia.
