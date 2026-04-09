# SolarShare

SolarShare is a decentralized platform that makes funding residential solar installations accessible to everyday investors. Instead of a single person or bank financing an entire solar system, SolarShare lets a group of investors collectively fund it by purchasing fractional shares — and earn returns from it over time.

![SolarShare Web App]<img width="1680" height="1050" alt="SolarShare Webpage Screenshot" src="https://github.com/user-attachments/assets/d96c9a95-af91-449b-91d9-c1dd062b7d89" />

---

## The Problem

Residential solar installations are expensive upfront (typically $15,000–$25,000), putting them out of reach for most homeowners. Traditional financing is slow, opaque, and inaccessible to small investors who might want to participate in the clean energy economy.

## The Solution

SolarShare tokenizes the loan behind a solar installation into tradeable fractional shares. A homeowner (Host) lists their project, investors fund it by buying shares, and the Host receives the capital to install the system. In return, investors earn two streams of income every month:

1. **Fixed yield** — the Host's monthly loan repayment, split proportionally among all shareholders
2. **Variable yield** — revenue from excess electricity exported back to the grid

All of this is managed automatically by smart contracts — no middlemen, no manual accounting, no trust required.

---

## Core Features

**For Hosts (homeowners)**

- List a solar project and set a fundraising target
- Receive capital once fully funded, with loan repayments spread over a chosen term
- On-chain reputation score that reflects payment history — good behavior builds credit, defaults are penalized

**For Investors**

- Browse and fund projects by purchasing fractional shares (as low as 1 share)
- Earn monthly dividends from both loan repayments and grid export revenue
- Claim earnings at any time — no gas-heavy distributions, just pull when ready
- Vote on maintenance proposals using share-weighted governance

**Revenue Waterfall**
Every time revenue enters the system, it is automatically split:

- 93% → Investor dividend pool
- 5% → Maintenance reserve (governed by token holders)
- 2% → Insurance pool

**Governance**
Token holders can submit and vote on maintenance proposals (e.g., approving a repair request). Proposals pass with >50% of the total token supply voting yes, and funds are released directly to the vendor.

**Default Protection**
If a Host misses a payment, anyone can declare a default on-chain. The Host's reputation score is slashed, the project is flagged, and investors retain the majority equity stake based on how much of the loan has been repaid.

---

## Tech Stack

| Layer            | Technology                                                   |
| ---------------- | ------------------------------------------------------------ |
| Smart Contracts  | Solidity, Foundry (Forge)                                    |
| Token Standards  | ERC-1155 (fractional shares), ERC-721 Soulbound (reputation) |
| Stablecoin       | USDC (mocked locally with 6 decimals)                        |
| Frontend         | Next.js 14, Tailwind CSS                                     |
| Web3 Integration | Wagmi, Viem, RainbowKit                                      |
| Local Blockchain | Anvil (part of Foundry)                                      |

---

## Repository Structure

```
solar-share/
├── backend/     # Solidity smart contracts, tests, and deployment scripts (Foundry)
├── frontend/    # Next.js web application
├── DEMO.md      # Step-by-step demo walkthrough (cast commands, oracle calls)
└── README.md    # This file
```

- Deploy contracts → [`backend/README.md`](./backend/README.md)
- Run the frontend → [`frontend/README.md`](./frontend/README.md)
- Run the demo → [`DEMO.md`](./DEMO.md)
