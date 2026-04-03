# Smart Contract Deployment & CLI Testing Guide

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

### 2. Required API Keys

| Service | Purpose | Get it here |
|---------|---------|-------------|
| **Alchemy** | Sepolia RPC endpoint | https://dashboard.alchemy.com → Create App → Ethereum Sepolia |
| **Etherscan** | Contract verification | https://etherscan.io/myapikey (free account) |
| **Sepolia ETH** | Gas for deployment | https://sepoliafaucet.com or https://faucets.chain.link/sepolia |

> **Private Key:** Export from MetaMask: Settings → Security & Privacy → Reveal Private Key. Use a **dedicated test wallet** — never use a wallet with real funds.

---

## Setup

```bash
cd solar-share/backend
```

### Create `.env` file

```bash
cp .env.example .env
```

Edit `.env`:

```env
# RPC URL from Alchemy dashboard (copy the HTTPS endpoint)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY

# MetaMask test wallet private key (no 0x prefix needed)
PRIVATE_KEY=your_private_key_here

# From https://etherscan.io/myapikey
ETHERSCAN_API_KEY=your_etherscan_api_key

# These get filled in after deployment:
MOCK_USDC=
SOLAR_PROJECT=
LOAN_MANAGER=
REVENUE_DISTRIBUTOR=
HOST_REPUTATION=
MAINTENANCE_DAO=
MOCK_GRID_ORACLE=
MOCK_KEEPER=
```

### Install dependencies & build

```bash
forge install
forge build
```

---

## Run Tests (Local — No ETH Needed)

Run the full test suite locally before deploying:

```bash
# All tests
forge test

# All tests with logs
forge test -vvv

# Specific test file
forge test --match-path test/unit/SolarProject.t.sol -vvv
forge test --match-path test/unit/LoanManager.t.sol -vvv
forge test --match-path test/unit/RevenueDistributor.t.sol -vvv
forge test --match-path test/unit/HostReputation.t.sol -vvv
forge test --match-path test/unit/MaintenanceDAO.t.sol -vvv
forge test --match-path test/integration/FullSystem.t.sol -vvv

# Specific test function
forge test --match-test test_FullLifecycle_HappyPath -vvv

# Gas report
forge test --gas-report

# Coverage report
forge coverage
```

---

## Deploy to Sepolia

```bash
source .env

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

The script will print all deployed addresses. Copy them into `.env`:

```env
MOCK_USDC=0x...
SOLAR_PROJECT=0x...
LOAN_MANAGER=0x...
REVENUE_DISTRIBUTOR=0x...
HOST_REPUTATION=0x...
MAINTENANCE_DAO=0x...
MOCK_GRID_ORACLE=0x...
MOCK_KEEPER=0x...
```

> **Verification:** After deployment, contracts are auto-verified on https://sepolia.etherscan.io. Search for any deployed address to confirm.

---

## CLI Testing with `cast`

All commands below use `cast send` (write) and `cast call` (read). Load env first:

```bash
source .env
```

Set your deployer address for convenience:
```bash
export MY_ADDRESS=$(cast wallet address $PRIVATE_KEY)
echo $MY_ADDRESS
```

---

### Step 1: Mint MockUSDC to Test Wallets

```bash
# Mint 100,000 USDC to yourself (6 decimals)
cast send $MOCK_USDC "mint(address,uint256)" \
  $MY_ADDRESS 100000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check your balance
cast call $MOCK_USDC "balanceOf(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# If you have multiple wallets, mint to each:
cast send $MOCK_USDC "mint(address,uint256)" \
  <INVESTOR_1_ADDRESS> 50000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

### Step 2: Mint Soulbound Token (Host Reputation)

```bash
# Mint SBT for yourself as host
cast send $HOST_REPUTATION "mintSBT(address)" \
  $MY_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check your reputation score (should be 1000)
cast call $HOST_REPUTATION "getScore(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 3: Create a Solar Project

```bash
# initializeProject(targetAmount, termMonths, totalShares)
# Target: $20,000 (20000 * 1e6), Term: 120 months, Shares: 1000
cast send $SOLAR_PROJECT "initializeProject(uint256,uint256,uint256)" \
  20000000000 120 1000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check project count
cast call $SOLAR_PROJECT "projectCount()" --rpc-url $SEPOLIA_RPC_URL

# Get project details (projectId = 1)
cast call $SOLAR_PROJECT "getProjectDetails(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 4: Fund the Project (Investors Buy Shares)

```bash
# Price per share = $20,000 / 1000 = $20 per share (20 * 1e6 = 20000000)

# Step 4a: Approve SolarProject to spend your USDC
# Buying 500 shares = $10,000 (10000 * 1e6)
cast send $MOCK_USDC "approve(address,uint256)" \
  $SOLAR_PROJECT 10000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Step 4b: Fund the project
# fundProject(projectId, numShares)
cast send $SOLAR_PROJECT "fundProject(uint256,uint256)" \
  1 500 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check shares owned
cast call $SOLAR_PROJECT "getInvestorShares(uint256,address)" \
  1 $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Check amount raised so far
cast call $SOLAR_PROJECT "getProjectDetails(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

> Repeat Step 4 with other investor wallets (use their private keys) until the project reaches $20,000 (1000 shares sold). Status will change to `Active` automatically.

---

### Step 5: Initialize the Loan

```bash
# initializeLoan(projectId, monthlyPayment, termMonths)
# Monthly payment: $200 (200 * 1e6)
cast send $LOAN_MANAGER "initializeLoan(uint256,uint256,uint256)" \
  1 200000000 120 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Verify loan details
cast call $LOAN_MANAGER "projectLoans(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 6: Make Monthly Payment (Host)

```bash
# Step 6a: Approve LoanManager to spend $200
cast send $MOCK_USDC "approve(address,uint256)" \
  $LOAN_MANAGER 200000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Step 6b: Pay monthly installment
cast send $LOAN_MANAGER "payMonthlyInstallment(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Verify payment
cast call $LOAN_MANAGER "projectLoans(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 7: Deposit Grid Revenue (Oracle)

```bash
# The MockGridOracle generates a random amount $20–$150
# Approve oracle to spend USDC first (or mint to oracle address)
cast send $MOCK_USDC "mint(address,uint256)" \
  $MOCK_GRID_ORACLE 1000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Trigger grid revenue deposit for project 1
cast send $MOCK_GRID_ORACLE "submitGridRevenue(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check total revenue accumulated
cast call $REVENUE_DISTRIBUTOR "projectRevenue(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 8: Execute Waterfall (93/5/2 Split)

```bash
# Anyone can call this
cast send $REVENUE_DISTRIBUTOR "executeWaterfall(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check dividend pool
cast call $REVENUE_DISTRIBUTOR "projectRevenue(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 9: Claim Dividends (Investor)

```bash
# Check claimable dividends
cast call $REVENUE_DISTRIBUTOR "getClaimableDividends(uint256,address)" \
  1 $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Claim dividends
cast send $REVENUE_DISTRIBUTOR "claimDividends(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Verify USDC received
cast call $MOCK_USDC "balanceOf(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

---

### Step 10: Check Equity Split

```bash
# View current equity split based on amortization
cast call $LOAN_MANAGER "calculateEquitySplit(uint256)" \
  1 --rpc-url $SEPOLIA_RPC_URL
# Returns: (hostPercent, investorPercent)
```

---

## Testing Default Scenario

Since we can't fast-forward real blockchain time, this is best done via Forge tests with `vm.warp`. But you can simulate on Sepolia by simply waiting 30+ days or using the following approach:

```bash
# 1. Check if project is in default (callable anytime)
cast call $LOAN_MANAGER "checkDefaultStatus(uint256)" \
  1 --rpc-url $SEPOLIA_RPC_URL

# 2. After 30+ days without payment, declare default (anyone can call)
cast send $LOAN_MANAGER "declareDefault(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 3. Check host reputation was slashed (should be 800 now)
cast call $HOST_REPUTATION "getScore(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# 4. Check project status (should be Defaulted = 2)
cast call $SOLAR_PROJECT "getProjectDetails(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

For faster default testing, use the local Forge test suite which can warp time:
```bash
forge test --match-test test_DefaultScenario -vvv
```

---

## Testing Governance (MaintenanceDAO)

```bash
# 1. Submit a maintenance proposal
# submitProposal(projectId, description, amount, vendor)
cast send $MAINTENANCE_DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Replace damaged inverter" 500000000 <VENDOR_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 2. Check proposal
cast call $MAINTENANCE_DAO "getProposal(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# 3. Vote YES on proposal (as token holder)
# castVote(proposalId, support)
cast send $MAINTENANCE_DAO "castVote(uint256,bool)" \
  1 true \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 4. Check voting power
cast call $MAINTENANCE_DAO "getVotingPower(uint256,address)" \
  1 $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# 5. After 7 days voting period ends, execute:
cast send $MAINTENANCE_DAO "executeProposal(uint256)" \
  1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 6. Verify vendor received funds
cast call $MOCK_USDC "balanceOf(address)" <VENDOR_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

---

## Testing Buyout

```bash
# Host triggers buyout at any point
# triggerBuyout(projectId, offerAmount)
# Offer $15,000 = 15000 * 1e6

# Approve SolarProject to spend the offer amount
cast send $MOCK_USDC "approve(address,uint256)" \
  $SOLAR_PROJECT 15000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send $SOLAR_PROJECT "triggerBuyout(uint256,uint256)" \
  1 15000000000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check equity split that was applied
cast call $LOAN_MANAGER "calculateEquitySplit(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## Useful Read Commands (Debugging)

```bash
# Full project state
cast call $SOLAR_PROJECT "getProjectDetails(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Full loan state
cast call $LOAN_MANAGER "projectLoans(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Full revenue pool state
cast call $REVENUE_DISTRIBUTOR "projectRevenue(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Host reputation details
cast call $HOST_REPUTATION "getReputationDetails(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Check if project is defaulted
cast call $LOAN_MANAGER "checkDefaultStatus(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Token balance (ERC-1155 shares)
cast call $SOLAR_PROJECT "balanceOf(address,uint256)" $MY_ADDRESS 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## Decode Raw Output

`cast call` returns hex. Decode it:

```bash
# Decode a uint256
cast --to-dec <HEX_OUTPUT>

# Or pipe directly
cast call $MOCK_USDC "balanceOf(address)" $MY_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL | cast --to-dec
```

---

## Complete Demo Flow (Quick Start)

```bash
source .env
MY_ADDRESS=$(cast wallet address $PRIVATE_KEY)

# 1. Mint USDC
cast send $MOCK_USDC "mint(address,uint256)" $MY_ADDRESS 100000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 2. Mint SBT
cast send $HOST_REPUTATION "mintSBT(address)" $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 3. Create project
cast send $SOLAR_PROJECT "initializeProject(uint256,uint256,uint256)" 20000000000 120 1000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 4. Approve + Fund (buying all 1000 shares yourself for simplicity)
cast send $MOCK_USDC "approve(address,uint256)" $SOLAR_PROJECT 20000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $SOLAR_PROJECT "fundProject(uint256,uint256)" 1 1000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 5. Initialize loan
cast send $LOAN_MANAGER "initializeLoan(uint256,uint256,uint256)" 1 200000000 120 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 6. Pay month 1
cast send $MOCK_USDC "approve(address,uint256)" $LOAN_MANAGER 200000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $LOAN_MANAGER "payMonthlyInstallment(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 7. Deposit grid revenue + execute waterfall
cast send $MOCK_USDC "mint(address,uint256)" $MOCK_GRID_ORACLE 1000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $MOCK_GRID_ORACLE "submitGridRevenue(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $REVENUE_DISTRIBUTOR "executeWaterfall(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 8. Claim dividends
cast call $REVENUE_DISTRIBUTOR "getClaimableDividends(uint256,address)" 1 $MY_ADDRESS --rpc-url $SEPOLIA_RPC_URL
cast send $REVENUE_DISTRIBUTOR "claimDividends(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

echo "Done! Check Etherscan: https://sepolia.etherscan.io/address/$SOLAR_PROJECT"
```
