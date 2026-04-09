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

## Build and Run

### 1. Install dependencies

```bash
cd frontend
npm install
```

### 2. Ensure contracts are deployed

The frontend reads contract addresses from `backend/deployments/31337.json`. Make sure Anvil is running and contracts are deployed before starting — see the backend README.

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

2. Import test accounts using Anvil's default private keys (see `backend/README.md` for the full list). Import at least one host account and two or three investor accounts.

3. Switch to the Anvil network in MetaMask and connect your wallet on the site.
