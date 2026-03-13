# ☀️ SolarShare

> A blockchain-based crowdfunding platform that allows homeowners to tokenize their roof space, enabling investors to fractionally own and govern solar assets and earn automated, transparent yields.

## Overview
SolarShare bridges the gap between decentralized finance (DeFi) and real-world renewable energy. By tokenizing the physical roof space of homeowners (Hosts) and fractionally dividing the investment into "SolarShares," retail investors can fund profitable 8-12 kWh solar systems without needing large upfront capital. 

The protocol utilizes smart contracts to automate the role of an investment bank—handling fundraising, asset valuation, governance, and the trustless distribution of monthly energy yields entirely on-chain using USDC.

## Key Features
* **Asset Tokenization (ERC-1155):** A single smart contract mints a unique "Project Deed" NFT (representing physical custody) alongside 1,000 fungible "SolarShare" tokens.
* **Trustless Waterfall Yields:** Energy revenue is automatically split into predefined buckets: **93%** to Investors, **5%** to a Maintenance Reserve, and **2%** to an Insurance Pool.
* **Oracle Automation:** Integrates with Chainlink to securely fetch off-chain IoT energy data (kWh) and automate revenue distribution without manual intervention.
* **Gas-Efficient Pull-Payments:** Investors claim their USDC dividends individually via a secure pull-payment architecture, ensuring scalability.
* **On-Chain Governance:** Token holders can vote on proposals (e.g., approving a Host's maintenance request) based on their fractional weight.

## System Architecture & Team Division
The platform utilizes a multi-layered decentralized approach, separated into three main workspaces:

### 1. Core Asset & Governance (Part 1)
* Manages the core `SolarShareToken.sol` registry.
* Handles the ERC-1155 minting, linear asset depreciation math (4% annual), and the >50% threshold DAO governance logic.

### 2. Oracle & Yield Automation (Part 2)
* Found in the `contracts/` directory (alongside Part 1).
* Manages the `EnergyOracle.sol` and `RevenueDistributor.sol` contracts.
* Handles Chainlink data fetching, mocked IoT energy feeds, the 93/5/2 USDC split, and the pull-payment withdrawal logic.

### 3. Frontend & Web3 Interface (Part 3)
* Found in the `frontend/` directory.
* Built with Next.js, Tailwind CSS, Wagmi, and Viem.
* Provides the marketplace UI for hosts to list roofs, and the Investor Dashboard for minting shares, claiming USDC, and voting.

## Repository Structure
\`\`\`text
solar-share/
├── contracts/       # Hardhat workspace containing all Solidity smart contracts and Oracle scripts
├── docs/            # System architecture and state machine diagrams (.mermaid & .png)
├── frontend/        # Next.js workspace containing the Web3 user interface
└── README.md        # Project overview
\`\`\`
*(Note: Please see the specific `README.md` files inside `/contracts` and `/frontend` for detailed setup and testing instructions for those environments).*
