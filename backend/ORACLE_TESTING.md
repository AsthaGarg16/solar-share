# Oracle & Revenue Distribution Testing Guide

Step-by-step reference for testing SolarShare's oracle integrations and revenue waterfall using Foundry (Forge/Anvil) and `cast`.

---

## Contract Roles at a Glance

| Contract | Role |
|---|---|
| `MockGridOracle` | Submits random grid revenue ($20–$150 USDC) to `RevenueDistributor` |
| `MockWeatherOracle` | Returns rainy-day counts; triggers payment forgiveness or DAO fast-track |
| `MockIoTSolarOracle` | Activates hardware kill-switch when a default is declared |
| `MockChainlinkKeeper` / `LoanAutomation` | Automates default detection across monitored projects |
| `RevenueDistributor` | Receives deposits, splits 93 / 5 / 2, exposes pull-based dividend claims |
| `LoanManager` | Validates payments, calls the weather oracle before declaring default |
| `MaintenanceDAO` | Democratic + parametric governance over the 5% maintenance reserve |

---

## Prerequisites

```bash
# Start Anvil in a dedicated terminal — keep it running
anvil

# Deploy all contracts (from backend/)
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

After deployment, read addresses from `deployments/31337.json`. Set shell variables for convenience:

```bash
# Run this block in the same terminal you’ll use for `cast` commands.
# If you see: "a value is required for '--rpc-url <URL>'", it usually means `$RPC` is unset/empty.
#
# Load all addresses into shell variables
USDC=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockUSDC'])")
SOLAR=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['solarProject'])")
LOAN=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['loanManager'])")
DIST=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['revenueDistributor'])")
ORACLE=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockGridOracle'])")
WEATHER=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['weatherOracle'])")
KEEPER=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockKeeper'])")
DAO=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['maintenanceDAO'])")
REPUTATION=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['hostReputation'])")

# Anvil accounts (private keys are constant)
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
HOST_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
INV1_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
INV2_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
INV3_KEY=0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b

# Wallet addresses (use *_ADDR names to avoid zsh's built-in `$HOST` variable)
HOST_ADDR=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
INV1_ADDR=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
INV2_ADDR=0x90F79bf6EB2c4f870365E785982E1f101E93b906
INV3_ADDR=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
export RPC=http://127.0.0.1:8545
```

---

## Part 1 — Baseline Project Setup

These steps create the funded project that all oracle tests depend on. Skip if already done.

### 1.1 Mint USDC to all wallets

```bash
# 100,000 USDC each (6-decimal, so 100_000 * 1e6 = 100000000000)
for ADDR in $HOST_ADDR $INV1_ADDR $INV2_ADDR $INV3_ADDR; do
  cast send $USDC "mint(address,uint256)" $ADDR 100000000000 \
    --rpc-url $RPC --private-key $DEPLOYER_KEY
done
```

### 1.2 Mint Soulbound Token (SBT) for the host

```bash
cast send $REPUTATION "mintSbt(address)" $HOST_ADDR \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify — should return 1000
cast call $REPUTATION "getScore(address)" $HOST_ADDR --rpc-url $RPC
```

### 1.3 Create a solar project

```bash
# initializeProject(name, targetAmount, termMonths, totalShares)
# $20,000 USDC = 20000 * 1e6 = 20000000000
cast send $SOLAR "initializeProject(string,uint256,uint256,uint256)" \
  "Rooftop Solar A" 20000000000 120 1000 \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify project was created (projectId = 1)
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC
```

### 1.4 Investors fund the project

```bash
# Each investor approves SolarProject then buys shares
# pricePerShare = 20000000000 / 1000 = 20000000 (=$20 per share)

# Investor 1 — 500 shares ($10,000)
cast send $USDC "approve(address,uint256)" $SOLAR 10000000000 \
  --rpc-url $RPC --private-key $INV1_KEY
cast send $SOLAR "fundProject(uint256,uint256)" 1 500 \
  --rpc-url $RPC --private-key $INV1_KEY

# Investor 2 — 300 shares ($6,000)
cast send $USDC "approve(address,uint256)" $SOLAR 6000000000 \
  --rpc-url $RPC --private-key $INV2_KEY
cast send $SOLAR "fundProject(uint256,uint256)" 1 300 \
  --rpc-url $RPC --private-key $INV2_KEY

# Investor 3 — 200 shares ($4,000)
cast send $USDC "approve(address,uint256)" $SOLAR 4000000000 \
  --rpc-url $RPC --private-key $INV3_KEY
cast send $SOLAR "fundProject(uint256,uint256)" 1 200 \
  --rpc-url $RPC --private-key $INV3_KEY
```

### 1.5 Host withdraws capital & initialises loan

```bash
# withdrawFunds: moves USDC to host and triggers LoanManager.initializeLoan
cast send $SOLAR "withdrawFunds(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify loan details
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC
# monthlyPayment = 20000000000 / 120 = 166666666 (~$166.67 USDC)
```

### 1.6 Fund MockGridOracle with USDC

The oracle must hold USDC to approve transfers to `RevenueDistributor`.

```bash
cast send $USDC "mint(address,uint256)" $ORACLE 10000000000 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Part 2 — Grid Oracle: Revenue Submission

### 2.1 Submit random grid revenue

```bash
# Random amount between $20–$150
cast send $ORACLE "submitGridRevenue(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Check what was deposited (totalRevenue resets to 0 after waterfall auto-fires)
cast call $DIST "projectRevenue(uint256)" 1 --rpc-url $RPC
```

### 2.2 Submit a fixed amount (deterministic testing)

```bash
# submitFixedRevenue(projectId, amount) — $80 USDC = 80 * 1e6 = 80000000
cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

> **Note:** `depositGridRevenue` in `RevenueDistributor` automatically calls the internal waterfall after each deposit, so `totalRevenue` resets to 0 immediately. Check `dividendPerShare` and pool balances instead.

### 2.3 Verify waterfall split after grid deposit

After a $80 grid revenue deposit the 93/5/2 split produces:

| Pool | Formula | Value |
|---|---|---|
| Dividend (93%) | 80000000 × 93 / 100 | 74,400,000 ($74.40) |
| Maintenance (5%) | 80000000 × 5 / 100 | 4,000,000 ($4.00) |
| Insurance (2%) | 80000000 − div − maint | 1,600,000 ($1.60) |

```bash
# Returns (totalRevenue, dividendPool, maintenanceReserve, insurancePool, dividendPerShare, currentMonth)
cast call $DIST "projectRevenue(uint256)" 1 --rpc-url $RPC
```

### 2.4 Set custom production data (IoT feed)

```bash
# setMockProduction(projectId, monthIndex, kWh)
cast send $ORACLE "setMockProduction(uint256,uint256,uint256)" 1 0 450 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Read it back
cast call $ORACLE "getProduction(uint256,uint256)" 1 0 --rpc-url $RPC
```

---

## Part 3 — Host Payment & Waterfall

### 3.1 Host makes a monthly loan payment

```bash
# Approve LoanManager to pull the monthly payment
MONTHLY=166666666
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY

cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

`payMonthlyInstallment` internally calls `revenueDistributor.depositHostPayment`, which fires the waterfall automatically.

### 3.2 Verify combined revenue split (host + grid)

After host payment ($166.67) + grid revenue ($80) = $246.67:

| Pool | Amount |
|---|---|
| Dividend (93%) | ~$229.40 |
| Maintenance (5%) | ~$12.33 |
| Insurance (2%) | ~$4.93 |

```bash
cast call $DIST "projectRevenue(uint256)" 1 --rpc-url $RPC
```

### 3.3 Manually trigger waterfall (if needed)

The waterfall fires automatically on each deposit. If you need to force it for any reason:

```bash
cast send $DIST "executeWaterfall(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Part 4 — Investor Dividend Claims

### 4.1 Check claimable dividends

```bash
# getClaimableDividends(projectId, investor)
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1_ADDR --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV2_ADDR --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV3_ADDR --rpc-url $RPC
```

Expected proportions (50% / 30% / 20% of dividend pool):

| Investor | Shares | Expected % |
|---|---|---|
| INV1 | 500 | 50% |
| INV2 | 300 | 30% |
| INV3 | 200 | 20% |

### 4.2 Claim dividends

```bash
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY
```

### 4.3 Verify pull-pattern correctness (multi-month accumulation)

Run several revenue cycles without claiming, then claim once:

```bash
# Month 2: host pays + grid deposits
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 --rpc-url $RPC --private-key $HOST_KEY
cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 --rpc-url $RPC --private-key $DEPLOYER_KEY

# Month 3
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC  # +30 days
cast rpc anvil_mine --rpc-url $RPC
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 --rpc-url $RPC --private-key $HOST_KEY
cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 --rpc-url $RPC --private-key $DEPLOYER_KEY

# INV1 claims 3 months at once — O(1) gas
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1_ADDR --rpc-url $RPC
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
```

---

## Part 5 — Weather Oracle

The weather oracle integrates with two contracts:
- **`LoanManager.declareDefault`**: excuses a default if rainy days > 15
- **`MaintenanceDAO.executeProposal`**: fast-tracks payout if rainy days ≥ 15 ("Act of God")

### 5.1 Set rainy-day data manually

```bash
# WeatherOracle (local) — mockSetRainyDays(projectId, days)
# Low rainfall — default proceeds normally
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# High rainfall — default excused / DAO fast-tracked
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

### 5.2 Trigger weather-based request (zip-code logic)

```bash
# Zip starting with '9' → 22 rainy days; any other → 5 rainy days
cast send $WEATHER "requestWeatherCheck(uint256,string)" 1 "90210" \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast call $WEATHER "getRainyDays(uint256)" 1 --rpc-url $RPC
```

---

## Part 6 — Default Detection & Declaration

### 6.1 Simulate a missed payment

```bash
# Advance time past the 30-day grace period
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC   # 31 days
cast rpc anvil_mine --rpc-url $RPC

# Confirm default status
cast call $LOAN "checkDefaultStatus(uint256)" 1 --rpc-url $RPC
# Returns: true (0x0000...0001)
```

### 6.2 Case A — Declare default (low rainfall, no forgiveness)

```bash
# Ensure rainy days ≤ 15 so the oracle won't excuse the missed payment
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Anyone can call declareDefault
cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Host reputation should drop by 200 (1000 → 800)
cast call $REPUTATION "getScore(address)" $HOST_ADDR --rpc-url $RPC

# Project status should be Defaulted (3)
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC

# IoT kill-switch should now be active
IOT=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['iotSolarOracle'])")
cast call $IOT "isKillswitchActive(uint256)" 1 --rpc-url $RPC
```

### 6.3 Case B — Weather excuses the missed payment

```bash
# Set high rainfall BEFORE calling declareDefault
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# declareDefault will emit DefaultExcused instead of DefaultDeclared
cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# nextPaymentDue has been extended by another 30 days — host can now pay
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC
```

### 6.4 Automated default via MockChainlinkKeeper

```bash
# Register project with the keeper
cast send $KEEPER "addProject(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Check if upkeep is needed
cast call $KEEPER "checkUpkeep()" --rpc-url $RPC

# Perform upkeep (declares default if overdue)
cast send $KEEPER "performUpkeep(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Or auto-scan all monitored projects
cast send $KEEPER "performAutoUpkeep()" \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Part 7 — Buyout After Default

```bash
# After default, host or LoanManager can trigger buyout
# At month 1: hostPercent ≈ 0 (0/120 * 100), investorPercent ≈ 100

# Check equity split
cast call $LOAN "calculateEquitySplit(uint256)" 1 --rpc-url $RPC

# Host approves offerAmount and triggers buyout ($15,000)
OFFER=15000000000
cast send $USDC "approve(address,uint256)" $SOLAR $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY

cast send $SOLAR "triggerBuyout(uint256,uint256)" 1 $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY

# Investors claim their buyout share
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY
```

---

## Part 8 — MaintenanceDAO Governance

Before testing governance you need a maintenance reserve. Run at least one revenue cycle (Part 3) to build it up.

### 8.1 Check maintenance reserve balance

```bash
cast call $DIST "getMaintenanceReserve(uint256)" 1 --rpc-url $RPC
```

### 8.2 Submit a repair proposal

```bash
VENDOR=0xa0Ee7A142d267C1f36714E4a8F75612F20a79720   # Anvil account 9
AMOUNT=500000000   # $500 USDC

# submitProposal(projectId, description, amount, vendor)
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Replace damaged inverter" $AMOUNT $VENDOR \
  --rpc-url $RPC --private-key $INV1_KEY
```

### 8.3 Investors vote

```bash
# castVote(proposalId, support)
# INV1 (500 tokens) — YES
cast send $DAO "castVote(uint256,bool)" 1 true \
  --rpc-url $RPC --private-key $INV1_KEY

# INV2 (300 tokens) — YES
cast send $DAO "castVote(uint256,bool)" 1 true \
  --rpc-url $RPC --private-key $INV2_KEY

# INV3 (200 tokens) — NO
cast send $DAO "castVote(uint256,bool)" 1 false \
  --rpc-url $RPC --private-key $INV3_KEY

# Check vote totals
cast call $DAO "getProposal(uint256)" 1 --rpc-url $RPC
```

### 8.4 Execute after 7-day voting period (Standard path)

```bash
# Advance 7 days
cast rpc anvil_increaseTime 604800 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

cast send $DAO "executeProposal(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Vendor should have received $500 USDC
cast call $USDC "balanceOf(address)" $VENDOR --rpc-url $RPC
```

### 8.5 Fast-track via weather oracle (Parametric path — no voting required)

```bash
# Submit a new proposal
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Emergency storm repair" 200000000 $VENDOR \
  --rpc-url $RPC --private-key $INV1_KEY

# Set rainy days >= 15
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Execute immediately — voting period doesn't matter
cast send $DAO "executeProposal(uint256)" 2 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

### 8.6 Rejected proposal (≤ 50% YES votes)

```bash
# Submit another proposal
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Optional upgrade" 300000000 $VENDOR \
  --rpc-url $RPC --private-key $INV1_KEY

# Only INV3 votes YES (20% — below 50% quorum)
cast send $DAO "castVote(uint256,bool)" 3 true \
  --rpc-url $RPC --private-key $INV3_KEY

cast rpc anvil_increaseTime 604800 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

# Make sure weather is calm so parametric path doesn't fire
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $DAO "executeProposal(uint256)" 3 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Proposal status should be Rejected (2)
cast call $DAO "getProposal(uint256)" 3 --rpc-url $RPC
```

---

## Running the Forge Test Suite

```bash
# All unit tests
forge test --match-path "test/unit/**" -vvv

# Integration tests only
forge test --match-path "test/integration/FullSystem.t.sol" -vvv

# Oracle-specific scenarios
forge test --match-test "test_Default" -vvv
forge test --match-test "test_Governance" -vvv
forge test --match-test "test_Revenue" -vvv

# Coverage report
forge coverage --report summary
```

---

## Quick Reference: Key Signatures

```bash
# MockGridOracle
submitGridRevenue(uint256 projectId)
submitFixedRevenue(uint256 projectId, uint256 amount)
setMockProduction(uint256 projectId, uint256 monthIndex, uint256 kwh)
getProduction(uint256 projectId, uint256 month) → uint256

# MockWeatherOracle
# WeatherOracle (local)
mockSetRainyDays(uint256 projectId, uint256 daysCount)
requestWeatherCheck(uint256 projectId, string zipCode) → bytes32
getRainyDays(uint256 projectId) → uint256

# MockChainlinkKeeper / LoanAutomation
addProject(uint256 projectId)
checkUpkeep() → (bool upkeepNeeded, uint256 projectId)
performUpkeep(uint256 projectId)
performAutoUpkeep()

# LoanManager
payMonthlyInstallment(uint256 projectId)
checkDefaultStatus(uint256 projectId) → bool
declareDefault(uint256 projectId)
calculateEquitySplit(uint256 projectId) → (uint256 hostPercent, uint256 investorPercent)

# RevenueDistributor
executeWaterfall(uint256 projectId)
claimDividends(uint256 projectId) → uint256
getClaimableDividends(uint256 projectId, address investor) → uint256
getMaintenanceReserve(uint256 projectId) → uint256

# MaintenanceDAO
submitProposal(uint256 projectId, string description, uint256 amount, address vendor) → uint256
castVote(uint256 proposalId, bool support)
executeProposal(uint256 proposalId)
getVotingPower(uint256 projectId, address voter) → uint256
```

---

## Time Manipulation Cheat Sheet

```bash
# Advance 30 days (next payment window)
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# Advance 31 days (trigger default window)
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# Advance 7 days (close governance vote)
cast rpc anvil_increaseTime 604800 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# Jump to month 60 (halfway through 120-month term)
cast rpc anvil_increaseTime 155520000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC
```
