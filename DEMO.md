# SolarShare — Full Demo Guide

Complete walkthrough of the SolarShare protocol: from cold start to governance, defaults, and buyouts. Every command is copy-pasteable against a local Anvil chain.

---

## What You Will Demonstrate

| Scene | What it shows |
|---|---|
| 1 — Setup | Deploy all contracts, fund wallets |
| 2 — Host | Mint reputation SBT, create a solar project |
| 3 — Investors | Three investors fund the project to 100% |
| 4 — Activation | Host withdraws capital, loan initialises |
| 5 — Revenue | Grid oracle submits energy revenue, waterfall splits 93/5/2 |
| 6 — Dividends | Investors pull their pro-rata dividends |
| 7 — Loan Payments | Host makes monthly repayments |
| 8 — Governance | Investors vote on a maintenance proposal; parametric fast-track |
| 9 — Default | Host misses payment, keeper declares default, reputation slashed, IoT kill-switch fires |
| 10 — Buyout | Host (or liquidator) buys out investors; tokens burned |

---

## Actors

| Role | Anvil Address | Private Key |
|---|---|---|
| Deployer / Owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Host | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Investor 1 (50%) | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| Investor 2 (30%) | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| Investor 3 (20%) | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b` |
| Vendor (maintenance) | `0xa0Ee7A142d267C1f36714E4a8F75612F20a79720` | Anvil account 9 |

---

## Scene 1 — Environment Setup

### Terminal A: Start Anvil

```bash
anvil
```

Leave this running throughout. Anvil prints 10 pre-funded accounts with 10,000 ETH each.

### Terminal B: Deploy contracts

```bash
cd backend

forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Addresses are written to `backend/deployments/31337.json` and read by the frontend automatically.

### Load addresses into your shell

```bash
# Run from backend/
USDC=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockUSDC'])")
SOLAR=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['solarProject'])")
LOAN=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['loanManager'])")
DIST=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['revenueDistributor'])")
ORACLE=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockGridOracle'])")
WEATHER=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['weatherOracle'])")
KEEPER=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['mockKeeper'])")
DAO=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['maintenanceDAO'])")
REPUTATION=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['hostReputation'])")
IOT=$(cat deployments/31337.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['iotSolarOracle'])")

# Shorthand keys & addresses
DEPLOYER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
HOST_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
INV1_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
INV2_KEY=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
INV3_KEY=0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b

HOST=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
INV1=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
INV2=0x90F79bf6EB2c4f870365E785982E1f101E93b906
INV3=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
VENDOR=0xa0Ee7A142d267C1f36714E4a8F75612F20a79720

RPC=http://127.0.0.1:8545
```

### Mint USDC to all participants

```bash
for ADDR in $HOST $INV1 $INV2 $INV3 $ORACLE; do
  cast send $USDC "mint(address,uint256)" $ADDR 100000000000 \
    --rpc-url $RPC --private-key $DEPLOYER_KEY
done

# Verify INV1 balance — should print 100000000000
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC
```

### Start the frontend (optional, separate terminal)

```bash
cd frontend
npm install
npm run dev
# Open http://localhost:3000
# Add Anvil network to MetaMask: RPC=http://127.0.0.1:8545, ChainID=31337
# Import host & investor private keys
```

---

## Scene 2 — Host: Mint SBT & Create Project

### 2.1 Mint Soulbound Token (one-time per host)

Every host must hold an SBT before their reputation can be tracked.

```bash
cast send $REPUTATION "mintSbt(address)" $HOST \
  --rpc-url $RPC --private-key $HOST_KEY

# Score starts at 1000
cast call $REPUTATION "getScore(address)" $HOST --rpc-url $RPC
# → 0x00...03e8  (1000 decimal)
```

### 2.2 Create the solar project

```bash
# initializeProject(name, targetAmount, termMonths, totalShares)
# $20,000 USDC | 120-month (10-year) term | 1,000 shares @ $20/share
cast send $SOLAR "initializeProject(string,uint256,uint256,uint256)" \
  "Rooftop Solar A" 20000000000 120 1000 \
  --rpc-url $RPC --private-key $HOST_KEY

# Read back — status=0 (Funding), isFunded=false, projectId=1
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC
```

**Expected state:**

| Field | Value |
|---|---|
| projectId | 1 |
| host | `0x7099...79C8` |
| targetAmount | 20,000,000,000 |
| totalShares | 1,000 |
| pricePerShare | 20,000,000 ($20) |
| status | Funding (0) |

---

## Scene 3 — Investors: Fund the Project

Each investor approves USDC then purchases shares. The project closes automatically when all 1,000 shares are sold.

### Investor 1 — 500 shares ($10,000, 50% stake)

```bash
cast send $USDC "approve(address,uint256)" $SOLAR 10000000000 \
  --rpc-url $RPC --private-key $INV1_KEY

cast send $SOLAR "fundProject(uint256,uint256)" 1 500 \
  --rpc-url $RPC --private-key $INV1_KEY

# Confirm share balance (ERC-1155 token ID = projectId = 1)
cast call $SOLAR "balanceOf(address,uint256)" $INV1 1 --rpc-url $RPC
# → 500
```

### Investor 2 — 300 shares ($6,000, 30% stake)

```bash
cast send $USDC "approve(address,uint256)" $SOLAR 6000000000 \
  --rpc-url $RPC --private-key $INV2_KEY

cast send $SOLAR "fundProject(uint256,uint256)" 1 300 \
  --rpc-url $RPC --private-key $INV2_KEY
```

### Investor 3 — 200 shares ($4,000, 20% stake) — closes the round

```bash
cast send $USDC "approve(address,uint256)" $SOLAR 4000000000 \
  --rpc-url $RPC --private-key $INV3_KEY

cast send $SOLAR "fundProject(uint256,uint256)" 1 200 \
  --rpc-url $RPC --private-key $INV3_KEY

# isFunded should now be true
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC
```

---

## Scene 4 — Activation: Host Withdraws Capital

`withdrawFunds` moves the pooled USDC to the host and simultaneously initialises the loan in `LoanManager`.

```bash
cast send $SOLAR "withdrawFunds(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

**What happens internally:**
1. `SolarProject` sets status → `Active`
2. `LoanManager.initializeLoan` is called with `monthlyPayment = targetAmount / termMonths = 166,666,666 (~$166.67)`
3. `HostReputation.incrementProjectsCreated` is called
4. $20,000 USDC is transferred to the host wallet

```bash
# Verify loan details
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC

# Host balance should have increased by $20,000
cast call $USDC "balanceOf(address)" $HOST --rpc-url $RPC

# Register project with the Chainlink keeper for automated monitoring
cast send $KEEPER "addProject(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Scene 5 — Revenue: Grid Oracle Submits Energy Data

The `MockGridOracle` holds USDC and deposits random grid revenue ($20–$150) into `RevenueDistributor`. The waterfall fires automatically on each deposit.

```bash
# Submit random grid revenue for project 1
cast send $ORACLE "submitGridRevenue(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Or submit a deterministic amount for the demo — $80 USDC
cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

**Waterfall result for $80 grid revenue (1000 shares):**

| Pool | Formula | Amount |
|---|---|---|
| Dividend (93%) | 80,000,000 × 93 / 100 | $74.40 |
| Maintenance (5%) | 80,000,000 × 5 / 100 | $4.00 |
| Insurance (2%) | remainder | $1.60 |
| dividendPerShare | 74,400,000 × 1e18 / 1000 | 74,400,000,000,000,000,000 |

```bash
# Check pool state: (totalRevenue, dividendPool, maintenanceReserve, insurancePool, dividendPerShare, currentMonth)
cast call $DIST "projectRevenue(uint256)" 1 --rpc-url $RPC
```

---

## Scene 6 — Dividends: Investors Claim

The dividend distribution is **pull-based** — gas is O(1) regardless of how many months have accumulated.

```bash
# Check claimable amounts
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1 --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV2 --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV3 --rpc-url $RPC
```

**Expected split of $74.40 dividend:**

| Investor | Shares | Claim |
|---|---|---|
| INV1 | 500 (50%) | ~$37.20 |
| INV2 | 300 (30%) | ~$22.32 |
| INV3 | 200 (20%) | ~$14.88 |

```bash
# Each investor claims their dividends
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY

# Verify USDC balances increased
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC
```

---

## Scene 7 — Loan Payments: Host Repays Monthly

```bash
MONTHLY=166666666   # $166.67 = 20000000000 / 120

# Month 1
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY

cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

**What happens internally:**
1. LoanManager pulls $166.67 from host
2. LoanManager approves RevenueDistributor, calls `depositHostPayment`
3. RevenueDistributor fires the waterfall on the host payment
4. `currentMonth` increments (now 1 / 120)

```bash
# Verify currentMonth = 1
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC

# Equity split at month 1: host ~0.8%, investors ~99.2%
cast call $LOAN "calculateEquitySplit(uint256)" 1 --rpc-url $RPC

# Advance time and make month 2 payment
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC   # +30 days
cast rpc anvil_mine --rpc-url $RPC

cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### Multi-month accumulation (skip-claim demo)

```bash
# Run months 3–5 without investors claiming
for i in 1 2 3; do
  cast rpc anvil_increaseTime 2592000 --rpc-url $RPC
  cast rpc anvil_mine --rpc-url $RPC
  cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
    --rpc-url $RPC --private-key $HOST_KEY
  cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
    --rpc-url $RPC --private-key $HOST_KEY
  cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 \
    --rpc-url $RPC --private-key $DEPLOYER_KEY
done

# INV1 claims 3 months at once — single O(1) transaction
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1 --rpc-url $RPC
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
```

---

## Scene 8 — Governance: Maintenance DAO

The 5% maintenance reserve accumulates with every revenue cycle. Investors vote to release funds to a repair vendor.

### 8.1 Check maintenance reserve

```bash
cast call $DIST "getMaintenanceReserve(uint256)" 1 --rpc-url $RPC
```

### 8.2 Submit a repair proposal

```bash
# submitProposal(projectId, description, amount, vendor)
REPAIR_AMOUNT=500000000   # $500

cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Replace damaged inverter" $REPAIR_AMOUNT $VENDOR \
  --rpc-url $RPC --private-key $INV1_KEY

# proposalId = 1; votingDeadline = now + 7 days
cast call $DAO "getProposal(uint256)" 1 --rpc-url $RPC
```

### 8.3 Investors vote

```bash
# INV1 (500 tokens) — YES
cast send $DAO "castVote(uint256,bool)" 1 true \
  --rpc-url $RPC --private-key $INV1_KEY

# INV2 (300 tokens) — YES
cast send $DAO "castVote(uint256,bool)" 1 true \
  --rpc-url $RPC --private-key $INV2_KEY

# INV3 (200 tokens) — NO
cast send $DAO "castVote(uint256,bool)" 1 false \
  --rpc-url $RPC --private-key $INV3_KEY

# Tally: yesVotes=800, noVotes=200
# Quorum needed: 1000 * 50% = 500 → 800 > 500 → PASSES
cast call $DAO "getProposal(uint256)" 1 --rpc-url $RPC
```

### 8.4 Standard path — execute after 7-day voting period

```bash
cast rpc anvil_increaseTime 604800 --rpc-url $RPC   # +7 days
cast rpc anvil_mine --rpc-url $RPC

# Make sure weather is calm (no parametric fast-track)
cast send $WEATHER "setRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $DAO "executeProposal(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Vendor received $500
cast call $USDC "balanceOf(address)" $VENDOR --rpc-url $RPC
```

### 8.5 Parametric path — emergency fast-track (no voting required)

```bash
# New proposal for a storm emergency
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Emergency storm damage repair" 200000000 $VENDOR \
  --rpc-url $RPC --private-key $INV2_KEY

# Set rainy days >= 15 (Act-of-God threshold)
cast send $WEATHER "setRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Execute immediately — voting deadline is irrelevant
cast send $DAO "executeProposal(uint256)" 2 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Vendor balance should have increased by another $200
cast call $USDC "balanceOf(address)" $VENDOR --rpc-url $RPC
```

### 8.6 Rejected proposal

```bash
# Submit a proposal that won't reach quorum
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Cosmetic panel cleaning" 100000000 $VENDOR \
  --rpc-url $RPC --private-key $INV1_KEY

# Only INV3 votes YES — 200 votes < 500 quorum
cast send $DAO "castVote(uint256,bool)" 3 true \
  --rpc-url $RPC --private-key $INV3_KEY

cast rpc anvil_increaseTime 604800 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

cast send $WEATHER "setRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $DAO "executeProposal(uint256)" 3 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Status should be Rejected (2); vendor balance unchanged
cast call $DAO "getProposal(uint256)" 3 --rpc-url $RPC
```

---

## Scene 9 — Default: Host Misses Payment

This scene shows what happens when a host stops paying. The Chainlink keeper (or any caller) detects the overdue payment, the oracle checks for weather excusal, reputation is slashed, and the IoT system kills the hardware.

### 9.1 Advance time past the payment deadline

```bash
# After last payment, nextPaymentDue = lastPayment + 30 days
# Advance 31 days to cross the deadline
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

# Confirm default status
cast call $LOAN "checkDefaultStatus(uint256)" 1 --rpc-url $RPC
# → 0x01 (true)
```

### 9.2 Keeper detects default

```bash
cast call $KEEPER "checkUpkeep()" --rpc-url $RPC
# → (true, 1)  — upkeep needed for project 1
```

### 9.3A Declare default (low rainfall — no forgiveness)

```bash
# Ensure weather oracle shows < 15 rainy days
cast send $WEATHER "setRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Declare — anyone can call this
cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

**Consequences:**
- `LoanDetails.isDefaulted = true`
- `HostReputation.slashScore(host, 200)` → score 1000 → 800
- `SolarProject.setProjectDefaulted(1)` → status = Defaulted (3)
- `IoTSolarOracle.triggerHardwareLock(1)` → kill-switch active

```bash
# Host score = 800
cast call $REPUTATION "getScore(address)" $HOST --rpc-url $RPC

# Project status = 3 (Defaulted)
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC

# Kill-switch active
cast call $IOT "isKillswitchActive(uint256)" 1 --rpc-url $RPC
# → true

# Host can no longer pay — this should revert
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### 9.3B Declare default (high rainfall — payment excused)

Run this instead of 9.3A to demonstrate the weather oracle forgiveness path:

```bash
cast send $WEATHER "setRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
# Emits DefaultExcused — nextPaymentDue extended by 30 more days

# Host can now make the late payment within the new window
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### 9.4 Automated default via keeper (alternative to 9.3A)

```bash
cast send $KEEPER "performUpkeep(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
# or scan all monitored projects:
cast send $KEEPER "performAutoUpkeep()" \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Scene 10 — Buyout: Liquidate Investor Positions

After default (or voluntary early exit), the host can buy back the project from investors. The buyout amount is split by the linear amortisation formula.

### 10.1 Check current equity split

```bash
# calculateEquitySplit(projectId) → (hostPercent, investorPercent)
cast call $LOAN "calculateEquitySplit(uint256)" 1 --rpc-url $RPC
# At month 1 of 120: hostPercent = 1*100/120 = 0, investorPercent = 100
# At month 60 of 120: hostPercent = 50, investorPercent = 50
```

### 10.2 Trigger buyout

```bash
OFFER=15000000000   # $15,000 buyout offer

# Host approves SolarProject to pull the offer amount
cast send $USDC "approve(address,uint256)" $SOLAR $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY

# triggerBuyout(projectId, offerAmount)
cast send $SOLAR "triggerBuyout(uint256,uint256)" 1 $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY
```

**What happens (at month 1, 0% host / 100% investors):**
- Host receives $0 (0% of $15,000)
- Investors receive $15,000 pro-rata (via pull pattern)

```bash
# Project status = BoughtOut (3)
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC

# Check buyout amounts available per investor
cast call $SOLAR "buyoutPerShare(uint256)" 1 --rpc-url $RPC
```

### 10.3 Investors claim their buyout

```bash
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY

# INV1 holds 500/1000 = 50% → should receive $7,500
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC

# Share tokens should be burned — balance = 0
cast call $SOLAR "balanceOf(address,uint256)" $INV1 1 --rpc-url $RPC
```

---

## Scenario Reference

### Happy Path Summary

```
Deploy → Mint SBT → Create Project → Fund (3 investors) → WithdrawFunds
  → [each month] Host pays + Grid oracle submits → Waterfall fires → Investors claim
  → [month 120] Loan completes → Host reputation +1 completed project
```

### Default → Buyout Summary

```
Deploy → ... → [month N] Host stops paying → Time +31 days
  → checkDefaultStatus = true
  → Weather oracle returns < 15 rainy days
  → declareDefault → reputation slashed → IoT kill-switch active
  → Host triggers buyout → investors claim buyout shares → tokens burned
```

### Weather Forgiveness Path

```
... → [month N] Host stops paying → Time +31 days
  → Weather oracle returns > 15 rainy days
  → declareDefault → DefaultExcused emitted → nextPaymentDue +30 days
  → Host pays within extended window → project continues normally
```

### Governance: Passed Proposal

```
Revenue accumulates → maintenanceReserve grows
  → Investor submits proposal → 7-day voting window
  → yesVotes > 50% of totalShares → executeProposal → vendor paid
```

### Governance: Parametric Fast-Track

```
Storm event → weather oracle getRainyDays >= 15
  → Any proposer submits emergency proposal
  → executeProposal called immediately (no need to wait 7 days)
  → vendor paid
```

---

## Running the Full Test Suite

```bash
cd backend

# All tests
forge test -vvv

# Only integration (full lifecycle)
forge test --match-path test/integration/FullSystem.t.sol -vvv

# Specific scenarios
forge test --match-test test_FullLifecycle_HappyPath -vvv
forge test --match-test test_DefaultScenario -vvv
forge test --match-test test_GovernanceProposal_Passed -vvv
forge test --match-test test_GovernanceProposal_Rejected -vvv
forge test --match-test test_BuyoutAtMonth60 -vvv

# Coverage
forge coverage --report summary
```

---

## Quick-Reference: Key Numbers

| Parameter | Value |
|---|---|
| Project target | $20,000 USDC |
| Shares | 1,000 @ $20 each |
| Loan term | 120 months (10 years) |
| Monthly payment | ~$166.67 |
| Dividend split | 93% |
| Maintenance split | 5% |
| Insurance split | 2% |
| Default penalty | −200 reputation points |
| Governance quorum | 50% of total token supply |
| Voting period | 7 days |
| Weather fast-track threshold | ≥ 15 rainy days |
| Payment grace period | 30 days |

## Time Manipulation

```bash
# +30 days (next payment window)
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# +31 days (trigger missed-payment default)
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# +7 days (close governance vote)
cast rpc anvil_increaseTime 604800 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# Jump to month 60 (50% amortisation)
cast rpc anvil_increaseTime 155520000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC
```
