# SolarShare — Demo Guide

Step-by-step walkthrough of the SolarShare protocol on a local Anvil chain.

**Assumes:** contracts deployed (see `backend/README.md`) and frontend running (see `frontend/README.md`).

---

## Actors

| Role             | Address                                      | Private Key                                                          |
| ---------------- | -------------------------------------------- | -------------------------------------------------------------------- |
| Deployer / Owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Host             | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Investor 1 (50%) | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| Investor 2 (30%) | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| Investor 3 (20%) | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926b` |
| Vendor           | `0xa0Ee7A142d267C1f36714E4a8F75612F20a79720` | Anvil account 9                                                      |

---

## Step 0 — Load environment

Run from the `backend/` directory after deployment. This reads addresses from the auto-generated deployment file and sets up shell variables for every command below.

```bash
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

---

## Step 1 — Mint test USDC to all participants

The MockGridOracle is pre-funded at deploy time. Mint to the host and investors.

```bash
for ADDR in $HOST $INV1 $INV2 $INV3; do
  cast send $USDC "mint(address,uint256)" $ADDR 100000000000 \
    --rpc-url $RPC --private-key $DEPLOYER_KEY
done

# Verify — should print 100000000000
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC
```

---

## Step 2 — Host: Mint Reputation SBT & Create Project

### 2.1 Mint Soulbound Token

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
# $20,000 USDC | 120-month term | 1,000 shares @ $20/share
cast send $SOLAR "initializeProject(string,uint256,uint256,uint256)" \
  "Rooftop Solar A" 20000000000 120 1000 \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify — status=0 (Funding), isFunded=false
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC
```

---

## Step 3 — Investors: Fund the Project

Each investor approves USDC then purchases shares. The project closes automatically when all 1,000 shares are sold.

### Investor 1 — 500 shares ($10,000, 50% stake)

```bash
cast send $USDC "approve(address,uint256)" $SOLAR 10000000000 \
  --rpc-url $RPC --private-key $INV1_KEY

cast send $SOLAR "fundProject(uint256,uint256)" 1 500 \
  --rpc-url $RPC --private-key $INV1_KEY

# ERC-1155 balance — should print 500
cast call $SOLAR "balanceOf(address,uint256)" $INV1 1 --rpc-url $RPC
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

# isFunded should now be true, status=Active
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC
```

---

## Step 4 — Activation: Host Withdraws Capital

`withdrawFunds` transfers the pooled USDC to the host and initialises the loan in `LoanManager`.

```bash
cast send $SOLAR "withdrawFunds(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify loan details
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC

# Host received $20,000
cast call $USDC "balanceOf(address)" $HOST --rpc-url $RPC

# Register project with the automation keeper
cast send $KEEPER "addProject(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

Monthly payment = $20,000 / 120 = ~$166.67 (166,666,666 in 6-decimal USDC).

---

## Step 5 — Revenue: Grid Oracle Submits Energy Data

The MockGridOracle holds USDC and deposits grid revenue into `RevenueDistributor`. The waterfall (93/5/2 split) fires automatically on each deposit.

```bash
# Submit random revenue ($20–$150)
cast send $ORACLE "submitGridRevenue(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Or submit a fixed amount — $80 USDC — for a predictable demo
cast send $ORACLE "submitFixedRevenue(uint256,uint256)" 1 80000000 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

**Waterfall result for $80:**

| Pool             | Formula              | Amount   |
| ---------------- | -------------------- | -------- |
| Dividend (93%)   | 80,000,000 × 93/100  | $74.40   |
| Maintenance (5%) | 80,000,000 × 5/100   | $4.00    |
| Insurance (2%)   | remainder            | $1.60    |

```bash
# Check pool state
cast call $DIST "projectRevenue(uint256)" 1 --rpc-url $RPC
```

---

## Step 6 — Dividends: Investors Claim

The dividend system is pull-based — O(1) gas regardless of how many months have accumulated.

```bash
# Check claimable amounts
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1 --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV2 --rpc-url $RPC
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV3 --rpc-url $RPC
```

Expected split of $74.40 (from $80 grid revenue):

| Investor | Shares | Claim   |
| -------- | ------ | ------- |
| INV1     | 500    | ~$37.20 |
| INV2     | 300    | ~$22.32 |
| INV3     | 200    | ~$14.88 |

```bash
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY

# Verify balances increased
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC
```

---

## Step 7 — Loan Payments: Host Repays Monthly

```bash
MONTHLY=166666666   # ~$166.67

# Month 1
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY

cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY

# Verify currentMonth = 1
cast call $LOAN "projectLoans(uint256)" 1 --rpc-url $RPC

# Equity split at month 1: host ~0.8%, investors ~99.2%
cast call $LOAN "calculateEquitySplit(uint256)" 1 --rpc-url $RPC
```

### Advance time and make month 2 payment

```bash
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC   # +30 days
cast rpc anvil_mine --rpc-url $RPC

cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### Multi-month accumulation (skip-claim demo)

Run months 3–5 without investors claiming, then have INV1 pull all at once in a single O(1) transaction:

```bash
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

# INV1 claims 3 months of accumulated dividends at once
cast call $DIST "getClaimableDividends(uint256,address)" 1 $INV1 --rpc-url $RPC
cast send $DIST "claimDividends(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
```

---

## Step 8 — Governance: Maintenance DAO

The 5% maintenance reserve accumulates with every revenue cycle. Token holders vote to release funds to a repair vendor.

### 8.1 Check maintenance reserve

```bash
cast call $DIST "getMaintenanceReserve(uint256)" 1 --rpc-url $RPC
```

### 8.2 Submit a repair proposal

```bash
REPAIR_AMOUNT=500000000   # $500

# submitProposal(projectId, description, amount, vendor)
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
# Quorum = 1000 * 50% = 500 → 800 > 500 → PASSES
cast call $DAO "getProposal(uint256)" 1 --rpc-url $RPC
```

### 8.4 Standard path — execute after 7-day voting period

```bash
cast rpc anvil_increaseTime 604800 --rpc-url $RPC   # +7 days
cast rpc anvil_mine --rpc-url $RPC

# Ensure weather is calm (no parametric fast-track)
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $DAO "executeProposal(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Vendor received $500
cast call $USDC "balanceOf(address)" $VENDOR --rpc-url $RPC
```

### 8.5 Parametric path — emergency fast-track (no voting wait required)

If the weather oracle reports ≥ 15 rainy days, the proposal executes immediately without waiting for the voting deadline.

```bash
# New proposal for a storm emergency
cast send $DAO "submitProposal(uint256,string,uint256,address)" \
  1 "Emergency storm damage repair" 200000000 $VENDOR \
  --rpc-url $RPC --private-key $INV2_KEY

# Set rainy days >= 15 (parametric trigger threshold)
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Execute immediately — no need to wait for voting deadline
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

# Ensure calm weather (prevent fast-track)
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $DAO "executeProposal(uint256)" 3 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Status = Rejected (2); vendor balance unchanged
cast call $DAO "getProposal(uint256)" 3 --rpc-url $RPC
```

---

## Step 9 — Default: Host Misses Payment

### 9.1 Advance time past the payment deadline

```bash
# Advance 31 days to cross the 30-day grace period
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

# Confirm default status
cast call $LOAN "checkDefaultStatus(uint256)" 1 --rpc-url $RPC
# → 0x01 (true)
```

### 9.2 Keeper detects default

```bash
cast call $KEEPER "checkUpkeep(bytes)" 0x --rpc-url $RPC
# → (true, <performData>)
```

### 9.3A Declare default (low rainfall — no forgiveness)

```bash
# Set < 15 rainy days (no weather excuse)
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 5 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

# Anyone can call declareDefault
cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

Consequences:
- `LoanDetails.isDefaulted = true`
- `HostReputation` score slashed by 200: 1000 → 800
- Project status set to `Defaulted`
- IoT kill-switch activated

```bash
# Host score = 800
cast call $REPUTATION "getScore(address)" $HOST --rpc-url $RPC

# Project status = Defaulted
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC

# Kill-switch active
cast call $IOT "isKillswitchActive(uint256)" 1 --rpc-url $RPC
# → true

# Host can no longer pay — this will revert
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### 9.3B Declare default (high rainfall — payment excused)

Use this instead of 9.3A to demonstrate weather oracle forgiveness:

```bash
cast send $WEATHER "mockSetRainyDays(uint256,uint256)" 1 20 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY

cast send $LOAN "declareDefault(uint256)" 1 \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
# Emits DefaultExcused — nextPaymentDue extended by 30 more days

# Host pays within the extended window
cast send $USDC "approve(address,uint256)" $LOAN $MONTHLY \
  --rpc-url $RPC --private-key $HOST_KEY
cast send $LOAN "payMonthlyInstallment(uint256)" 1 \
  --rpc-url $RPC --private-key $HOST_KEY
```

### 9.4 Automated default via keeper

```bash
# Keeper calls performUpkeep with the encoded project data
cast send $KEEPER "performUpkeep(bytes)" \
  $(cast abi-encode "f(uint256,uint256)" 0 1) \
  --rpc-url $RPC --private-key $DEPLOYER_KEY
```

---

## Step 10 — Buyout: Liquidate Investor Positions

### 10.1 Check current equity split

```bash
# (hostPercent, investorPercent)
cast call $LOAN "calculateEquitySplit(uint256)" 1 --rpc-url $RPC
# At month 1 of 120: host=0, investors=100
# At month 60 of 120: host=50, investors=50
```

### 10.2 Trigger buyout

```bash
OFFER=15000000000   # $15,000 buyout offer

cast send $USDC "approve(address,uint256)" $SOLAR $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY

# triggerBuyout(projectId, offerAmount)
cast send $SOLAR "triggerBuyout(uint256,uint256)" 1 $OFFER \
  --rpc-url $RPC --private-key $HOST_KEY

# Project status = BoughtOut
cast call $SOLAR "getProjectDetails(uint256)" 1 --rpc-url $RPC

# Per-share buyout amount available
cast call $SOLAR "buyoutPerShare(uint256)" 1 --rpc-url $RPC
```

### 10.3 Investors claim their buyout

```bash
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV1_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV2_KEY
cast send $SOLAR "claimBuyout(uint256)" 1 --rpc-url $RPC --private-key $INV3_KEY

# INV1 held 50% → receives $7,500 (at 100% investor equity)
cast call $USDC "balanceOf(address)" $INV1 --rpc-url $RPC

# Share tokens are burned — balance = 0
cast call $SOLAR "balanceOf(address,uint256)" $INV1 1 --rpc-url $RPC
```

---

## Quick Reference

### Time manipulation

```bash
# +30 days (next payment window)
cast rpc anvil_increaseTime 2592000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# +31 days (trigger missed-payment default)
cast rpc anvil_increaseTime 2678400 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# +7 days (close governance vote)
cast rpc anvil_increaseTime 604800 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC

# Jump to month 60 (50% amortisation for buyout demo)
cast rpc anvil_increaseTime 155520000 --rpc-url $RPC && cast rpc anvil_mine --rpc-url $RPC
```

### Key numbers

| Parameter              | Value                          |
| ---------------------- | ------------------------------ |
| Project target         | $20,000 USDC                   |
| Shares                 | 1,000 @ $20 each               |
| Loan term              | 120 months (10 years)          |
| Monthly payment        | ~$166.67 (166,666,666)         |
| Dividend split         | 93%                            |
| Maintenance split      | 5%                             |
| Insurance split        | 2%                             |
| Default penalty        | −200 reputation points         |
| Governance quorum      | 50% of total token supply      |
| Voting period          | 7 days                         |
| Weather fast-track     | ≥ 15 rainy days                |
| Payment grace period   | 30 days                        |
