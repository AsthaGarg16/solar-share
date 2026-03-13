# SolarShare Smart Contracts

This directory contains the core Solidity smart contracts that power the SolarShare protocol. To ensure security, modularity, and ease of testing, the system is separated into two logical layers: **Asset Tokenization** and **Automated Revenue**.

---

## Part 1: Core Asset & Governance

### `SolarShareToken.sol`
This is the master registry for the physical solar asset and its fractional owners. 
* **Multi-Token Standard (ERC-1155):** Mints a single "Project Deed" NFT (representing physical custody of the roof) alongside 1,000 fungible "SolarShare" tokens.
* **Valuation & Buyouts:** Contains the mathematical logic to calculate the asset's depreciating Book Value (4% annual depreciation) to facilitate fair-market buyouts.
* **DAO Governance:** Enables token holders to vote on key proposals (e.g., approving a host's `requestMaintenanceFunds`), requiring a >50% threshold to pass.

---

## Part 2: Oracle & Yield Automation

### `EnergyOracle.sol`
This contract acts as the trustless bridge between the physical solar panels and the blockchain.
* **Chainlink Consumer:** securely fetches off-chain IoT energy data (kWh produced) to prove the solar panels are generating value.
* **Automation Trigger:** Works with Chainlink Automation to read the new data and automatically trigger the deposit sequence, completely removing the need for manual human accounting.

### `RevenueDistributor.sol`
The financial engine of the protocol that securely routes USDC stablecoin payments.
* **Trustless Waterfall:** Automatically splits all incoming USDC revenue into predefined buckets: **93%** to the Investor Pool, **5%** to the Maintenance Reserve, and **2%** to the Insurance Pool.
* **Pull-Payment Architecture:** Implements a gas-efficient `claimDividend()` function. Instead of the contract "pushing" USDC to hundreds of wallets (which is expensive and prone to failure), investors interact with this contract to safely "pull" their exact allocated balance.
