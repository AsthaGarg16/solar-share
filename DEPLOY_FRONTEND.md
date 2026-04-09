# Frontend Deployment & UI Testing Guide

## Prerequisites

### 1. Node.js

```bash
node --version   # Should be v18+
npm --version
```

Install Node.js if needed: https://nodejs.org (use LTS version)

### 2. Required API Keys

| Service                      | Purpose                              | Get it here                                   |
| ---------------------------- | ------------------------------------ | --------------------------------------------- |
| **WalletConnect Project ID** | Wallet connection modal (RainbowKit) | https://cloud.walletconnect.com → New Project |

> You also need **deployed contract addresses** from the smart contract deployment step. See `DEPLOY_CONTRACTS.md`.

---

## Setup

```bash
cd solar-share/frontend
npm install
```

### Create `.env.local`

```bash
cp .env.local.example .env.local
```

Edit `.env.local` with your values:

```env
# From https://cloud.walletconnect.com
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id

# Contract addresses from deployment (DEPLOY_CONTRACTS.md)
NEXT_PUBLIC_MOCK_USDC=0x...
NEXT_PUBLIC_SOLAR_PROJECT=0x...
NEXT_PUBLIC_LOAN_MANAGER=0x...
NEXT_PUBLIC_REVENUE_DISTRIBUTOR=0x...
NEXT_PUBLIC_HOST_REPUTATION=0x...
NEXT_PUBLIC_MAINTENANCE_DAO=0x...
```

> **Note:** All frontend env vars must start with `NEXT_PUBLIC_` to be accessible in the browser.

---

## Run Locally

```bash
npm run dev
```

Open: http://localhost:3000

---

## MetaMask Setup for Testing

1. Install MetaMask: https://metamask.io/download
2. Import your test wallet private key: MetaMask → Import Account → Private Key
3. Add MockUSDC token to MetaMask:
   - Open MetaMask → Import tokens
   - Token contract address: `<your MOCK_USDC address>`
   - Symbol: `mUSDC`, Decimals: `6`

---

## UI Walkthrough — Testing Each Feature

### Connect Wallet

1. Click **"Connect Wallet"** in the top-right navbar
2. Select MetaMask (or any injected wallet)
3. Approve connection in MetaMask popup
4. Confirm you're on **Localhost** network

---

### Mint Test USDC

Before doing anything, you need mock USDC. This can be done via the frontend if a mint button exists, or via CLI (see `DEPLOY_CONTRACTS.md` Step 1).

> If the UI doesn't have a mint button, run this once:
>
> ```bash
> cd ../backend && source .env
> cast send $MOCK_USDC "mint(address,uint256)" <YOUR_ADDRESS> 100000000000 \
>   --rpc-url $RPC_URL --private-key $PRIVATE_KEY
> ```

---

### Create a Solar Project (Host Flow)

1. Navigate to `/host` or click **"Become a Host"**
2. If you don't have a Soulbound Token yet, click **"Mint SBT"**
   - MetaMask will prompt — approve the transaction
   - Your reputation score (1000) will appear after confirmation
3. Fill in the project form:
   - **Target Amount:** `20000` (= $20,000)
   - **Term (months):** `120`
   - **Total Shares:** `1000`
4. Click **"Create Project"** → Approve MetaMask transaction
5. After confirmation, you'll be redirected to the project page

---

### Invest in a Project (Investor Flow)

1. Navigate to `/explore` to see all projects
2. Click on a project card to open the detail page (`/projects/1`)
3. In the **"Invest in This Project"** widget:
   - Enter number of shares (e.g., `100`)
   - Click **"1. Approve USDC"** — MetaMask prompts to approve spending
   - Wait for approval transaction to confirm
   - Click **"2. Invest"** — MetaMask prompts to fund the project
4. After confirmation, your share count updates on the page

> **Price per share** = Total Target / Total Shares = $20,000 / 1000 = **$20 per share**
>
> Buying 100 shares = $2,000 USDC

---

### Initialize the Loan (After Project is Fully Funded)

Once 100% funded (all 1000 shares sold), the host must withdraw the funds to trigger the loan:

1. On the host dashboard (`/host/dashboard`) or project page
2. Click **"Withdraw Funds & Initialize Loan"**
3. Approve MetaMask transaction

---

### Make Monthly Payment (Host)

1. Go to `/host/dashboard`
2. See **"Next Payment Due"** date and amount ($200)
3. Click **"Pay Installment"**
   - Step 1: Approve $200 USDC → confirm in MetaMask
   - Step 2: Pay → confirm in MetaMask
4. Payment counter increments, next due date updates

---

### Deposit Grid Revenue + Execute Waterfall

The MockGridOracle can be triggered manually:

```bash
# From backend/ directory
source .env
cast send $MOCK_USDC "mint(address,uint256)" $MOCK_GRID_ORACLE 1000000000 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
cast send $MOCK_GRID_ORACLE "submitGridRevenue(uint256)" 1 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

Then execute the waterfall (anyone can call this — do it from the UI or CLI):

```bash
cast send $REVENUE_DISTRIBUTOR "executeWaterfall(uint256)" 1 \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

After this, investors will see claimable dividends appear on their dashboard.

---

### Claim Dividends (Investor)

1. Go to `/dashboard` (investor dashboard)
2. See **"Claimable Dividends"** amount in USDC
3. Click **"Claim Now"**
4. Approve MetaMask transaction
5. USDC arrives in your wallet

> Expected amounts (with 1000 shares, $280 total revenue):
>
> - 500 shares (50%) → ~$130.20
> - 300 shares (30%) → ~$78.12
> - 200 shares (20%) → ~$52.08

---

### Governance — Submit Repair Proposal

1. Navigate to `/governance`
2. Click **"Create Proposal"**
3. Fill in the form:
   - **Project ID:** `1`
   - **Description:** `Replace damaged inverter`
   - **Amount:** `500` (= $500 USDC)
   - **Vendor Address:** any anvil wallet address
4. Click **"Submit Proposal"** → Approve MetaMask transaction
5. Proposal appears in the list with 7-day voting countdown

---

### Governance — Vote on Proposal

1. On `/governance`, click a proposal card
2. See current YES/NO vote totals
3. Click **"Vote YES"** or **"Vote NO"**
   - Your voting power = number of project shares you hold
   - Non-holders cannot vote
4. Approve MetaMask transaction
5. Vote tally updates

---

### Governance — Execute Proposal (After 7 Days)

1. After the voting deadline passes, the **"Execute Proposal"** button becomes active
2. Anyone can click it — approve MetaMask transaction
3. If YES votes > 50% of total token supply:
   - Status changes to **Executed**
   - Vendor receives the USDC
   - Maintenance reserve decreases
4. Otherwise:
   - Status changes to **Rejected**
   - No funds transferred

---

## Network Info

| Parameter    | Value                   |
| ------------ | ----------------------- |
| Network Name | Localhost               |
| Chain ID     | 31337                   |
| RPC URL      | `http://127.0.0.1:8545` |
