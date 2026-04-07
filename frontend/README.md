# SolarShare — Frontend

Next.js web application for the SolarShare protocol. Connects to smart contracts running on a local Anvil blockchain via MetaMask.

---

## Project Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── page.tsx              # Home / landing page
│   │   ├── explore/              # Browse all projects
│   │   ├── projects/[id]/        # Individual project detail page
│   │   ├── host/                 # Host dashboard (create project, pay installments)
│   │   ├── dashboard/            # Investor dashboard (portfolio, dividends)
│   │   ├── governance/           # Maintenance DAO proposals and voting
│   │   └── layout.tsx            # Root layout with wallet providers
│   ├── components/
│   │   ├── Navbar.tsx
│   │   ├── InvestWidget.tsx      # Buy shares in a project
│   │   ├── ClaimDividends.tsx    # Claim earned dividends
│   │   ├── ProposalCard.tsx      # Display a governance proposal
│   │   ├── CreateProposal.tsx    # Submit a new maintenance proposal
│   │   └── MintButton.tsx        # Mint reputation SBT
│   ├── hooks/
│   │   └── useContracts.ts       # All wagmi read/write hooks for every contract
│   └── contracts/
│       ├── abis/                 # TypeScript ABI files for each contract
│       └── addresses.ts          # Reads contract addresses from backend/deployments/31337.json
├── public/
├── package.json
└── next.config.ts
```

---

## Prerequisites

- [Node.js](https://nodejs.org/) v18+
- [MetaMask](https://metamask.io/) browser extension
- Contracts deployed locally (see [`backend/README.md`](../backend/README.md))

---

## Setup

### 1. Install dependencies

```bash
cd frontend
npm install
```

### 2. Ensure contracts are deployed

The frontend reads contract addresses from `backend/deployments/31337.json`. This file is generated automatically when you run the deploy script. Make sure Anvil is running and contracts are deployed before starting the frontend — see the backend README for instructions.

### 3. Start the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## Connecting MetaMask

1. Add the Anvil network to MetaMask:
   - **Network name:** `Anvil`
   - **RPC URL:** `http://127.0.0.1:8545`
   - **Chain ID:** `31337`
   - **Currency symbol:** `ETH`

2. Import test accounts using Anvil's default private keys (see `backend/README.md` for the full list). You'll want at least one host account and two or three investor accounts.

3. Switch to the Anvil network in MetaMask and connect your wallet on the site.

---

## Demo Flow

Once the backend is running and MetaMask is connected:

1. **Mint USDC** — use the Dashboard page or the Mint button to give each wallet test USDC
2. **Create a project** — switch to the host account, go to Host Dashboard → Create Project
3. **Invest** — switch to investor accounts, browse Explore, and buy shares
4. **Withdraw funds & start loan** — once fully funded, the host goes to My Projects and clicks "Withdraw Funds & Start Loan"
5. **Pay monthly installment** — host pays from the My Projects overview each month
6. **Claim dividends** — investors claim from the project detail page or Dashboard
7. **Governance** — submit and vote on maintenance proposals from the Governance page
