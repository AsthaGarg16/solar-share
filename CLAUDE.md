## 📖 Instructions

```
I want to build Solar Share, a decentralized solar financing platform.
This CLAUDE.md file contains the complete specification.

Please implement this project step by step:
1. Set up the Foundry project structure
2. Implement all 7 smart contracts (4 core + 3 mocks)
3. Write comprehensive tests (80%+ coverage)
4. Create deployment scripts for Sepolia
5. Build a minimal Next.js frontend for interaction

Work through each section sequentially. After completing each major section,
wait for my confirmation before proceeding to the next.

Start with: PROJECT SETUP
```

---

# PROJECT OVERVIEW

## Executive Summary

Solar Share is a decentralized protocol that funds residential solar installations through a hybrid Web3 loan and equity model. Investors fund a fixed-term loan via fractional NFTs (ERC-1155) and receive dual yield:

1. **Fixed yield:** Host's monthly loan repayment ($200/month)
2. **Variable yield:** Excess grid export revenue ($20-$150/month)

The system secures the loan through:

- Automated trustless revenue splitting (93% to investors, 5% maintenance, 2% insurance)
- On-chain identity slashing via Soulbound Tokens for defaults
- Algorithmic buyout curve based on loan amortization

## Tech Stack

- **Smart Contracts:** Foundry (Forge), Solidity ^0.8.20
- **Testing:** Forge test framework
- **Deployment:** Sepolia testnet
- **Standards:** ERC-1155 (fractional shares), ERC-20 (USDC), ERC-721 (Soulbound)
- **Dependencies:** OpenZeppelin contracts, Chainlink (mocked)
- **Frontend:** Next.js 14, Wagmi v2, Viem, RainbowKit

## System Architecture

**5 Core Contracts:**

1. **SolarProject.sol** - Capital formation, ERC-1155 fractional ownership, buyouts
2. **LoanManager.sol** - Payment tracking, default detection, equity split calculation
3. **RevenueDistributor.sol** - 93/5/2 waterfall, pull-based dividends
4. **HostReputation.sol** - Soulbound ERC-721, credit score, slashing
5. **MaintenanceDAO.sol** - Governance engine for 5% maintenance reserve, proposal voting

**3 Mock Contracts:**

1. **MockUSDC.sol** - 6-decimal stablecoin for testing
2. **MockGridOracle.sol** - Simulates grid revenue ($20-$150/month)
3. **MockChainlinkKeeper.sol** - Automates default detection

---

# SECTION 1: PROJECT SETUP

## Initialize Foundry Project

Create a new Foundry project with this exact structure:

```
backend/
├── contracts/
│   ├── core/
│   │   ├── SolarProject.sol
│   │   ├── LoanManager.sol
│   │   ├── RevenueDistributor.sol
│   │   └── HostReputation.sol
│   ├── mocks/
│   │   ├── MockUSDC.sol
│   │   ├── MockGridOracle.sol
│   │   └── MockChainlinkKeeper.sol
│   └── interfaces/
│       ├── ISolarProject.sol
│       ├── ILoanManager.sol
│       ├── IRevenueDistributor.sol
│       └── IHostReputation.sol
├── test/
│   ├── unit/
│   │   ├── SolarProject.t.sol
│   │   ├── LoanManager.t.sol
│   │   ├── RevenueDistributor.t.sol
│   │   └── HostReputation.t.sol
│   ├── integration/
│   │   └── FullSystem.t.sol
│   └── Base.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── MockOracle.s.sol
├── foundry.toml
└── README.md
```

## Configure foundry.toml

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.20"
optimizer = true
optimizer_runs = 200
via_ir = true

[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
```

## Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0
forge install smartcontractkit/chainlink@v2.9.0
```

## Create .env Template

```env
# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Private Keys (for deployment)
PRIVATE_KEY=your_private_key_here

# Etherscan
ETHERSCAN_API_KEY=your_etherscan_api_key

# Contract Addresses (filled after deployment)
MOCK_USDC=
SOLAR_PROJECT=
LOAN_MANAGER=
REVENUE_DISTRIBUTOR=
HOST_REPUTATION=
MAINTENANCE_DAO=
MOCK_GRID_ORACLE=
MOCK_KEEPER=
```

---

# SECTION 2: MOCK CONTRACTS

## MockUSDC.sol

**Location:** `src/mocks/MockUSDC.sol`

**Requirements:**

- ERC20 with 6 decimals (like real USDC)
- Mint function for testing
- Constructor mints 1,000,000 USDC to deployer
- Anyone can call mint() for testing purposes

**Implementation:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000 * 10**6); // 1M USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
```

**Test:** `test/unit/MockUSDC.t.sol`

Test cases:

- Decimals are 6
- Minting works
- Transfers work
- Balance tracking accurate

---

# SECTION 3: CORE CONTRACT 1 - SolarProject.sol

**Location:** `src/core/SolarProject.sol`

## Requirements

**Purpose:** Handle capital formation, fractional ownership via ERC-1155, and buyouts

**State Variables:**

```solidity
struct Project {
    uint256 projectId;
    address host;
    uint256 targetAmount;        // e.g., $20,000 USDC (6 decimals)
    uint256 amountRaised;
    uint256 totalShares;         // Total ERC-1155 tokens to issue
    uint256 sharesSold;
    uint256 pricePerShare;       // USDC per share
    uint256 termMonths;          // e.g., 120 months
    uint256 startDate;
    bool isFunded;
    bool isBoughtOut;
    ProjectStatus status;
}

enum ProjectStatus {
    Funding,    // Accepting investments
    Active,     // Fully funded, loan active
    Defaulted,  // Host defaulted on payment
    BoughtOut   // Buyout completed
}

mapping(uint256 => Project) public projects;
uint256 public projectCount;
IERC20 public immutable usdc;
```

**Key Functions:**

```solidity
/// @notice Host creates a new solar project
/// @param targetAmount Total USDC to raise (6 decimals)
/// @param termMonths Loan term in months (e.g., 120)
/// @param totalShares Number of ERC-1155 tokens to issue
/// @return projectId The ID of the created project
function initializeProject(
    uint256 targetAmount,
    uint256 termMonths,
    uint256 totalShares
) external returns (uint256 projectId);

/// @notice Investor funds a project by purchasing shares
/// @param projectId The project to fund
/// @param numShares Number of shares to purchase
function fundProject(uint256 projectId, uint256 numShares) external;

/// @notice Triggers buyout of investor shares
/// @param projectId The project to buy out
/// @param offerAmount Total USDC offer for buyout
/// @dev Calculates equity split from LoanManager
function triggerBuyout(uint256 projectId, uint256 offerAmount) external;

/// @notice Get full project details
function getProjectDetails(uint256 projectId)
    external
    view
    returns (Project memory);

/// @notice Get investor's shares in a project
function getInvestorShares(uint256 projectId, address investor)
    external
    view
    returns (uint256);

/// @notice Get total shares for a project (for dividend calculations)
function getTotalShares(uint256 projectId)
    external
    view
    returns (uint256);
```

**Events:**

```solidity
event ProjectCreated(
    uint256 indexed projectId,
    address indexed host,
    uint256 targetAmount,
    uint256 termMonths
);

event ProjectFunded(
    uint256 indexed projectId,
    address indexed investor,
    uint256 numShares,
    uint256 amount
);

event SharesMinted(
    uint256 indexed projectId,
    address indexed investor,
    uint256 numShares
);

event BuyoutTriggered(
    uint256 indexed projectId,
    uint256 offerAmount,
    uint256 hostShare,
    uint256 investorShare
);

event ProjectStatusChanged(
    uint256 indexed projectId,
    ProjectStatus newStatus
);
```

**Business Logic:**

1. **Initialize Project:**
   - Only host can create
   - Calculate pricePerShare = targetAmount / totalShares
   - Set status to Funding
   - Emit ProjectCreated

2. **Fund Project:**
   - Must be in Funding status
   - Transfer USDC from investor to contract
   - Mint ERC-1155 shares to investor
   - Update amountRaised and sharesSold
   - If amountRaised == targetAmount: set status to Active, set isFunded = true
   - Emit ProjectFunded and SharesMinted

3. **Trigger Buyout:**
   - Must be in Active status
   - Get equity split from LoanManager.calculateEquitySplit()
   - hostAmount = offerAmount \* hostPercent / 100
   - investorAmount = offerAmount \* investorPercent / 100
   - Transfer hostAmount to host
   - Transfer investorAmount to contract (for pro-rata distribution)
   - Distribute investorAmount to all shareholders proportionally
   - Burn all investor tokens
   - Set status to BoughtOut
   - Emit BuyoutTriggered

**Access Control:**

- initializeProject: Anyone can be a host
- fundProject: Anyone can invest during Funding status
- triggerBuyout: Only host or LoanManager can trigger

**Integration Points:**

- Imports ILoanManager for equity split calculation
- Imports IERC20 for USDC transfers
- Implements ERC1155

---

## Test: SolarProject.t.sol

**Location:** `test/unit/SolarProject.t.sol`

**Test Cases (Minimum 25):**

```solidity
// Setup
- Deploy MockUSDC
- Deploy SolarProject
- Create test users (host, investor1, investor2, investor3)
- Mint USDC to all test users

// Initialization Tests
- ✅ Initialize project as host
- ✅ ProjectId increments correctly
- ✅ Project details stored correctly
- ✅ Initial status is Funding
- ✅ PricePerShare calculated correctly

// Funding Tests
- ✅ Single investor can fund project
- ✅ Multiple investors can fund project
- ✅ Shares minted correctly (ERC-1155)
- ✅ USDC transferred from investor to contract
- ✅ AmountRaised updates correctly
- ✅ SharesSold updates correctly
- ✅ Cannot fund more than totalShares
- ✅ Cannot fund after project fully funded
- ✅ Status changes to Active when targetAmount reached
- ✅ isFunded set to true when complete
- ✅ Cannot fund when status is Active
- ✅ Emits ProjectFunded event
- ✅ Emits SharesMinted event

// Buyout Tests
- ✅ Cannot buyout before project funded
- ✅ Cannot buyout during Funding status
- ✅ Host can trigger buyout
- ✅ Buyout calls LoanManager for equity split
- ✅ Buyout at month 1: host gets ~1%, investors get ~99%
- ✅ Buyout at month 60: 50/50 split
- ✅ Buyout distributes investor share pro-rata
- ✅ Investor with 10% shares gets 10% of investor portion
- ✅ All investor tokens burned after buyout
- ✅ Status changes to BoughtOut
- ✅ Emits BuyoutTriggered event

// Edge Cases
- ✅ Cannot fund with 0 shares
- ✅ Cannot initialize with 0 targetAmount
- ✅ Cannot initialize with 0 termMonths
- ✅ Handles dust amounts correctly
```

**Coverage Target:** >85%

---

# SECTION 4: CORE CONTRACT 2 - LoanManager.sol

**Location:** `src/core/LoanManager.sol`

## Requirements

**Purpose:** Track monthly payments, detect defaults, calculate equity splits, trigger reputation slashing

**State Variables:**

```solidity
struct LoanDetails {
    uint256 projectId;
    uint256 monthlyPayment;      // Fixed amount (e.g., $200 USDC)
    uint256 termMonths;          // Total months (e.g., 120)
    uint256 currentMonth;        // Current month (1-indexed)
    uint256 lastPaymentDate;     // Timestamp of last payment
    uint256 nextPaymentDue;      // Timestamp when next payment due
    uint256 totalPaid;           // Total USDC paid so far
    uint256 totalOwed;           // Total USDC owed (monthlyPayment * termMonths)
    bool isDefaulted;
    bool isCompleted;            // All payments made
}

mapping(uint256 => LoanDetails) public projectLoans;
ISolarProject public immutable solarProject;
IRevenueDistributor public revenueDistributor;
IHostReputation public immutable hostReputation;
IERC20 public immutable usdc;

uint256 public constant PAYMENT_GRACE_PERIOD = 30 days;
uint256 public constant DEFAULT_PENALTY = 200; // -200 reputation points
```

**Key Functions:**

```solidity
/// @notice Initialize loan for a funded project
/// @param projectId The project ID
/// @param monthlyPayment Monthly payment in USDC (6 decimals)
/// @param termMonths Total loan term
function initializeLoan(
    uint256 projectId,
    uint256 monthlyPayment,
    uint256 termMonths
) external;

/// @notice Host makes monthly payment
/// @param projectId The project to pay for
function payMonthlyInstallment(uint256 projectId) external;

/// @notice Check if project is in default
/// @param projectId The project to check
/// @return isDefault True if payment overdue
function checkDefaultStatus(uint256 projectId)
    external
    view
    returns (bool isDefault);

/// @notice Declare default (callable by Keeper or anyone)
/// @param projectId The project in default
function declareDefault(uint256 projectId) external;

/// @notice Calculate equity split based on amortization
/// @param projectId The project
/// @return hostPercent Percentage owned by host (0-100)
/// @return investorPercent Percentage owned by investors (0-100)
function calculateEquitySplit(uint256 projectId)
    external
    view
    returns (uint256 hostPercent, uint256 investorPercent);

/// @notice Get current month for a project
function getCurrentMonth(uint256 projectId)
    external
    view
    returns (uint256);

/// @notice Set revenue distributor address
function setRevenueDistributor(address _distributor) external;
```

**Events:**

```solidity
event LoanInitialized(
    uint256 indexed projectId,
    uint256 monthlyPayment,
    uint256 termMonths
);

event PaymentReceived(
    uint256 indexed projectId,
    uint256 month,
    uint256 amount,
    uint256 timestamp
);

event DefaultDeclared(
    uint256 indexed projectId,
    uint256 missedMonth,
    address host
);

event LoanCompleted(
    uint256 indexed projectId,
    uint256 totalPaid
);
```

**Business Logic:**

1. **Initialize Loan:**
   - Can only be called once per project
   - Project must be in Active status (fully funded)
   - Set monthlyPayment, termMonths, currentMonth = 0
   - Calculate totalOwed = monthlyPayment \* termMonths
   - Set nextPaymentDue = block.timestamp + 30 days
   - Emit LoanInitialized

2. **Pay Monthly Installment:**
   - Must not be defaulted
   - Must not be completed
   - Transfer monthlyPayment USDC from host to contract
   - Call revenueDistributor.depositHostPayment(projectId, monthlyPayment)
   - Increment currentMonth
   - Update lastPaymentDate = block.timestamp
   - Update nextPaymentDue = block.timestamp + 30 days
   - Update totalPaid += monthlyPayment
   - If totalPaid == totalOwed: set isCompleted = true, emit LoanCompleted
   - Emit PaymentReceived

3. **Check Default Status:**
   - If isDefaulted: return true
   - If block.timestamp > nextPaymentDue: return true
   - Else: return false

4. **Declare Default:**
   - Require checkDefaultStatus() returns true
   - Set isDefaulted = true
   - Get host address from SolarProject
   - Call hostReputation.slashScore(host, DEFAULT_PENALTY)
   - Change project status to Defaulted in SolarProject
   - Emit DefaultDeclared

5. **Calculate Equity Split (Amortization):**
   - Linear amortization formula:
   - hostPercent = (currentMonth \* 100) / termMonths
   - investorPercent = 100 - hostPercent
   - Examples:
     - Month 0: Host 0%, Investors 100%
     - Month 1: Host 0.83%, Investors 99.17%
     - Month 60: Host 50%, Investors 50%
     - Month 120: Host 100%, Investors 0%

**Access Control:**

- initializeLoan: Only callable by SolarProject contract after funding complete
- payMonthlyInstallment: Only callable by project host
- declareDefault: Callable by anyone (Keeper, investors, public)
- setRevenueDistributor: Only owner

---

## Test: LoanManager.t.sol

**Location:** `test/unit/LoanManager.t.sol`

**Test Cases (Minimum 30):**

```solidity
// Setup
- Deploy all contracts
- Create and fund a project
- Initialize loan

// Initialization Tests
- ✅ Initialize loan with correct parameters
- ✅ Cannot initialize twice
- ✅ Cannot initialize unfunded project
- ✅ Only SolarProject can initialize
- ✅ TotalOwed calculated correctly
- ✅ NextPaymentDue set correctly

// Payment Tests
- ✅ Host can make payment
- ✅ Payment transfers USDC
- ✅ Payment calls distributor.depositHostPayment
- ✅ CurrentMonth increments after payment
- ✅ LastPaymentDate updated
- ✅ NextPaymentDue updated (+30 days)
- ✅ TotalPaid updated
- ✅ Cannot pay twice in same period
- ✅ Cannot pay if defaulted
- ✅ Cannot pay after loan completed
- ✅ Emits PaymentReceived event

// Default Detection Tests
- ✅ checkDefaultStatus false when current
- ✅ checkDefaultStatus true after deadline
- ✅ checkDefaultStatus true if isDefaulted flag set
- ✅ Time-based default detection accurate

// Default Declaration Tests
- ✅ Can declare default after deadline
- ✅ Cannot declare default before deadline
- ✅ Default sets isDefaulted flag
- ✅ Default calls hostReputation.slashScore
- ✅ Default changes project status to Defaulted
- ✅ Cannot pay after default declared
- ✅ Emits DefaultDeclared event

// Equity Split Tests
- ✅ Month 0: Host 0%, Investors 100%
- ✅ Month 1: Host 0.83%, Investors 99.17%
- ✅ Month 12: Host 10%, Investors 90%
- ✅ Month 60: Host 50%, Investors 50%
- ✅ Month 119: Host 99.17%, Investors 0.83%
- ✅ Month 120: Host 100%, Investors 0%
- ✅ Equity split sums to 100%

// Completion Tests
- ✅ Loan marked complete after final payment
- ✅ Cannot pay after completion
- ✅ Emits LoanCompleted event

// Edge Cases
- ✅ Payment exactly on deadline
- ✅ Payment one second late
- ✅ Multiple months missed
- ✅ Zero monthly payment (should revert)
```

**Coverage Target:** >85%

---

# SECTION 5: CORE CONTRACT 3 - RevenueDistributor.sol

**Location:** `src/core/RevenueDistributor.sol`

## Requirements

**Purpose:** Route all revenue through 93/5/2 waterfall using pull-based dividend pattern

**State Variables:**

```solidity
struct RevenuePool {
    uint256 totalRevenue;           // Accumulator for current period
    uint256 dividendPool;           // 93% - accumulates over time
    uint256 maintenanceReserve;     // 5% - locked treasury
    uint256 insurancePool;          // 2% - insurance fund
    uint256 dividendPerShare;       // Accumulator (scaled by 1e18)
    uint256 lastWaterfallTimestamp;
}

mapping(uint256 => RevenuePool) public projectRevenue;
mapping(uint256 => mapping(address => uint256)) public claimedDividends;

ISolarProject public immutable solarProject;
IERC20 public immutable usdc;
ILoanManager public loanManager;

uint256 public constant DIVIDEND_PERCENTAGE = 93;
uint256 public constant MAINTENANCE_PERCENTAGE = 5;
uint256 public constant INSURANCE_PERCENTAGE = 2;
uint256 public constant PRECISION = 1e18;
```

**Key Functions:**

```solidity
/// @notice Oracle deposits grid revenue
/// @param projectId The project
/// @param amount USDC amount (6 decimals)
function depositGridRevenue(uint256 projectId, uint256 amount) external;

/// @notice LoanManager deposits host payment
/// @param projectId The project
/// @param amount USDC amount (6 decimals)
function depositHostPayment(uint256 projectId, uint256 amount) external;

/// @notice Execute waterfall to split revenue 93/5/2
/// @param projectId The project
function executeWaterfall(uint256 projectId) external;

/// @notice Investor claims their dividends
/// @param projectId The project
/// @return claimed Amount of USDC claimed
function claimDividends(uint256 projectId) external returns (uint256 claimed);

/// @notice Calculate claimable dividends for investor
/// @param projectId The project
/// @param investor The investor address
/// @return claimable Amount claimable in USDC
function getClaimableDividends(uint256 projectId, address investor)
    external
    view
    returns (uint256 claimable);

/// @notice Withdraw from maintenance reserve (governance)
/// @param projectId The project
/// @param amount Amount to withdraw (6 decimals)
/// @param recipient Address to receive funds
function withdrawMaintenance(uint256 projectId, uint256 amount, address recipient)
    external;

/// @notice Withdraw from insurance pool (governance)
function withdrawInsurance(uint256 projectId, uint256 amount) external;
```

**Events:**

```solidity
event GridRevenueDeposited(
    uint256 indexed projectId,
    uint256 amount,
    uint256 timestamp
);

event HostPaymentDeposited(
    uint256 indexed projectId,
    uint256 amount,
    uint256 month
);

event WaterfallExecuted(
    uint256 indexed projectId,
    uint256 totalRevenue,
    uint256 dividendAmount,
    uint256 maintenanceAmount,
    uint256 insuranceAmount
);

event DividendsClaimed(
    uint256 indexed projectId,
    address indexed investor,
    uint256 amount
);

event MaintenanceWithdrawn(
    uint256 indexed projectId,
    uint256 amount,
    address recipient
);

event InsuranceWithdrawn(
    uint256 indexed projectId,
    uint256 amount,
    address recipient
);
```

**Business Logic:**

1. **Deposit Grid Revenue:**
   - Transfer USDC from caller to contract
   - Add to totalRevenue accumulator
   - Emit GridRevenueDeposited

2. **Deposit Host Payment:**
   - Only callable by LoanManager
   - USDC already held by contract (transferred to LoanManager first)
   - Add to totalRevenue accumulator
   - Emit HostPaymentDeposited

3. **Execute Waterfall:**
   - Get totalRevenue for period
   - Calculate splits:
     - dividendAmount = totalRevenue \* 93 / 100
     - maintenanceAmount = totalRevenue \* 5 / 100
     - insuranceAmount = totalRevenue \* 2 / 100
   - Update pools:
     - dividendPool += dividendAmount
     - maintenanceReserve += maintenanceAmount
     - insurancePool += insuranceAmount
   - Update dividend per share (CRITICAL - pull pattern):
     - totalShares = solarProject.getTotalShares(projectId)
     - dividendPerShare += (dividendAmount \* PRECISION) / totalShares
   - Reset totalRevenue = 0
   - Update lastWaterfallTimestamp
   - Emit WaterfallExecuted

4. **Claim Dividends (PULL PATTERN):**
   - Get investor's shares from SolarProject
   - Calculate total owed: `(shares * dividendPerShare) / PRECISION`
   - Get already claimed: `claimedDividends[projectId][investor]`
   - Calculate claimable: `totalOwed - alreadyClaimed`
   - Require claimable > 0
   - Update claimedDividends[projectId][investor] = totalOwed
   - Transfer claimable USDC to investor
   - Emit DividendsClaimed
   - Return claimable

5. **Get Claimable Dividends (View):**
   - Same calculation as claimDividends but read-only
   - Returns: `(shares * dividendPerShare / PRECISION) - claimedDividends[projectId][investor]`

**Example:**

Month 1:

- Host pays: $200
- Grid pays: $80
- Total: $280

Waterfall:

- Dividend (93%): $260.40
- Maintenance (5%): $14.00
- Insurance (2%): $5.60

If totalShares = 1000:

- dividendPerShare += (260.40 \* 1e18) / 1000 = 260,400,000,000,000,000

Investor A owns 100 shares (10%):

- totalOwed = (100 \* 260,400,000,000,000,000) / 1e18 = $26.04
- claimable = $26.04 - 0 = $26.04

After claim:

- claimedDividends[projectId][investorA] = 260,400,000,000,000,000

Month 2:

- Another $280 deposited
- dividendPerShare += another 260,400,000,000,000,000
- dividendPerShare now = 520,800,000,000,000,000

Investor A:

- totalOwed = (100 \* 520,800,000,000,000,000) / 1e18 = $52.08
- claimable = $52.08 - $26.04 = $26.04 (month 2 only)

**Access Control:**

- depositGridRevenue: Only MockGridOracle
- depositHostPayment: Only LoanManager
- executeWaterfall: Anyone can call
- claimDividends: Anyone can claim their own
- withdrawMaintenance: Only MAINTAINER_ROLE (granted to MaintenanceDAO)
- withdrawInsurance: Only owner/governance

---

## Test: RevenueDistributor.t.sol

**Location:** `test/unit/RevenueDistributor.t.sol`

**Test Cases (Minimum 25):**

```solidity
// Setup
- Deploy all contracts
- Create and fund project with multiple investors
- Set up revenue streams

// Deposit Tests
- ✅ Oracle can deposit grid revenue
- ✅ Grid revenue adds to totalRevenue
- ✅ LoanManager can deposit host payment
- ✅ Host payment adds to totalRevenue
- ✅ Emits deposit events

// Waterfall Tests
- ✅ Execute waterfall with $280 revenue
- ✅ Dividend pool receives exactly 93%
- ✅ Maintenance reserve receives exactly 5%
- ✅ Insurance pool receives exactly 2%
- ✅ Percentages sum to 100%
- ✅ DividendPerShare updated correctly
- ✅ TotalRevenue reset to 0 after waterfall
- ✅ Can execute multiple waterfalls
- ✅ Emits WaterfallExecuted event

// Dividend Claim Tests (Pull Pattern)
- ✅ Investor can claim dividends
- ✅ Claim amount matches share percentage
- ✅ Investor with 10% shares gets 10% of dividends
- ✅ Cannot claim more than owed
- ✅ Cannot claim twice without new revenue
- ✅ ClaimedDividends updated after claim
- ✅ USDC transferred to investor
- ✅ Emits DividendsClaimed event

// Multi-Period Tests
- ✅ Dividends accumulate over multiple months
- ✅ Investor claims all accumulated at once
- ✅ Partial claims work correctly
- ✅ Multiple investors claim proportionally

// Edge Cases
- ✅ Zero revenue waterfall (no change)
- ✅ Dust amounts handled correctly
- ✅ Single investor claims everything
- ✅ Rounding precision accurate

// Gas Tests
- ✅ claimDividends gas is O(1) regardless of investor count
- ✅ executeWaterfall gas reasonable
```

**Coverage Target:** >85%

---

# SECTION 6: CORE CONTRACT 4 - HostReputation.sol

**Location:** `src/core/HostReputation.sol`

## Requirements

**Purpose:** Soulbound ERC-721 token representing on-chain credit score

**State Variables:**

```solidity
struct ReputationScore {
    uint256 score;                  // Starts at 1000
    uint256 projectsCreated;
    uint256 projectsCompleted;
    uint256 projectsDefaulted;
    uint256 totalSlashed;
    bool exists;
}

mapping(address => ReputationScore) public hostScores;
mapping(address => uint256) public hostToTokenId;
mapping(uint256 => address) public tokenIdToHost;

uint256 private _nextTokenId = 1;
uint256 public constant INITIAL_SCORE = 1000;
uint256 public constant MIN_SCORE = 0;

bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
```

**Key Functions:**

```solidity
/// @notice Mint soulbound token to new host
/// @param host The host address
/// @return tokenId The minted token ID
function mintSBT(address host) external returns (uint256 tokenId);

/// @notice Slash host's reputation score
/// @param host The host to slash
/// @param penaltyAmount Amount to deduct from score
function slashScore(address host, uint256 penaltyAmount) external;

/// @notice Get reputation score for host
/// @param host The host address
/// @return score Current score (0-1000+)
function getScore(address host) external view returns (uint256 score);

/// @notice Increment projects completed
/// @param host The host
function incrementProjectsCompleted(address host) external;

/// @notice Get full reputation details
function getReputationDetails(address host)
    external
    view
    returns (ReputationScore memory);
```

**Events:**

```solidity
event SBTMinted(
    address indexed host,
    uint256 indexed tokenId,
    uint256 initialScore
);

event ScoreSlashed(
    address indexed host,
    uint256 penaltyAmount,
    uint256 newScore
);

event ProjectCompleted(
    address indexed host,
    uint256 totalCompleted
);
```

**Business Logic:**

1. **Mint SBT:**
   - Require host doesn't already have token
   - Mint ERC-721 token to host
   - Initialize ReputationScore:
     - score = INITIAL_SCORE (1000)
     - exists = true
     - projectsCreated = 1
   - Map host <-> tokenId
   - Emit SBTMinted

2. **Slash Score:**
   - Only callable by SLASHER_ROLE (LoanManager)
   - Require host has SBT
   - Calculate new score:
     - If score >= penaltyAmount: score -= penaltyAmount
     - Else: score = 0
   - Increment projectsDefaulted
   - Add to totalSlashed
   - Emit ScoreSlashed

3. **Soulbound Transfer Override:**
   - Override `_beforeTokenTransfer`
   - Allow minting (from == address(0))
   - Revert all other transfers with "Soulbound: cannot transfer"

4. **Increment Projects Completed:**
   - Only callable by SLASHER_ROLE or owner
   - Increment projectsCompleted
   - Emit ProjectCompleted

**Access Control:**

- mintSBT: Anyone (auto-called on first project creation)
- slashScore: Only SLASHER_ROLE (granted to LoanManager)
- incrementProjectsCompleted: Only SLASHER_ROLE or owner

---

## Test: HostReputation.t.sol

**Location:** `test/unit/HostReputation.t.sol`

**Test Cases (Minimum 15):**

```solidity
// Setup
- Deploy HostReputation
- Create test hosts
- Grant SLASHER_ROLE to test contract

// Minting Tests
- ✅ Mint SBT to host
- ✅ TokenId increments
- ✅ Initial score is 1000
- ✅ ReputationScore created correctly
- ✅ Cannot mint twice to same host
- ✅ Emits SBTMinted event

// Soulbound Tests
- ✅ Cannot transfer token
- ✅ Cannot transfer from host to another address
- ✅ Cannot approve token
- ✅ Token locked to host forever

// Slashing Tests
- ✅ SLASHER_ROLE can slash score
- ✅ Slash 200 from 1000 = 800
- ✅ Slash 500 from 800 = 300
- ✅ Slash 400 from 300 = 0 (floor)
- ✅ Cannot slash below 0
- ✅ ProjectsDefaulted increments
- ✅ TotalSlashed accumulates
- ✅ Only SLASHER_ROLE can slash
- ✅ Emits ScoreSlashed event

// Completion Tests
- ✅ Increment projects completed
- ✅ Counter increases correctly
- ✅ Emits ProjectCompleted event

// View Tests
- ✅ getScore returns correct value
- ✅ getReputationDetails returns full struct
```

**Coverage Target:** >85%

---

# SECTION 7: CORE CONTRACT 5 - MaintenanceDAO.sol

**Location:** `src/core/MaintenanceDAO.sol`

## Requirements

**Purpose:** Democratic governance for the 5% maintenance reserve. Token holders vote on repair proposals, and funds only unlock when majority consensus is reached.

**State Variables:**

```solidity
struct Proposal {
    uint256 proposalId;
    uint256 projectId;
    address proposer;
    string description;
    uint256 amount;              // USDC requested (6 decimals)
    address payable vendor;      // Wallet to receive payment if approved
    uint256 votingDeadline;      // Timestamp when voting ends
    uint256 yesVotes;            // Total token weight voting YES
    uint256 noVotes;             // Total token weight voting NO
    bool executed;
    bool passed;
    ProposalStatus status;
}

enum ProposalStatus {
    Active,      // Currently accepting votes
    Passed,      // Voting ended, passed
    Rejected,    // Voting ended, rejected
    Executed     // Passed and funds transferred
}

mapping(uint256 => Proposal) public proposals;
mapping(uint256 => mapping(address => bool)) public hasVoted; // proposalId => voter => voted
uint256 public proposalCount;

ISolarProject public immutable solarProject;
IRevenueDistributor public immutable revenueDistributor;
IERC20 public immutable usdc;

uint256 public constant VOTING_PERIOD = 7 days;
uint256 public constant QUORUM_PERCENTAGE = 50; // 50% of total tokens must vote YES
```

**Key Functions:**

```solidity
/// @notice Submit a repair/maintenance proposal
/// @param projectId The project needing maintenance
/// @param description Details of the repair (e.g., "Replace inverter")
/// @param amount USDC amount requested (6 decimals)
/// @param vendor Verified repairman's wallet address
/// @return proposalId The created proposal ID
function submitProposal(
    uint256 projectId,
    string memory description,
    uint256 amount,
    address payable vendor
) external returns (uint256 proposalId);

/// @notice Cast vote on a proposal
/// @param proposalId The proposal to vote on
/// @param support True = YES, False = NO
function castVote(uint256 proposalId, bool support) external;

/// @notice Execute proposal after voting period
/// @param proposalId The proposal to execute
/// @dev Only executes if YES votes > 50% of total token supply
function executeProposal(uint256 proposalId) external;

/// @notice Get proposal details
function getProposal(uint256 proposalId)
    external
    view
    returns (Proposal memory);

/// @notice Check if voter has voted on proposal
function hasVotedOnProposal(uint256 proposalId, address voter)
    external
    view
    returns (bool);

/// @notice Get voting power for an address
/// @param projectId The project
/// @param voter The voter address
/// @return votes Number of votes (equal to token balance)
function getVotingPower(uint256 projectId, address voter)
    external
    view
    returns (uint256 votes);
```

**Events:**

```solidity
event ProposalSubmitted(
    uint256 indexed proposalId,
    uint256 indexed projectId,
    address indexed proposer,
    string description,
    uint256 amount,
    address vendor,
    uint256 votingDeadline
);

event VoteCast(
    uint256 indexed proposalId,
    address indexed voter,
    bool support,
    uint256 votingPower
);

event ProposalExecuted(
    uint256 indexed proposalId,
    bool passed,
    uint256 yesVotes,
    uint256 noVotes
);

event FundsTransferred(
    uint256 indexed proposalId,
    address indexed vendor,
    uint256 amount
);
```

**Business Logic:**

1. **Submit Proposal:**
   - Anyone can submit (investors, host, public)
   - Require amount <= maintenance reserve available
   - Require vendor address is not zero
   - Create Proposal:
     - proposalId = ++proposalCount
     - Set all fields
     - votingDeadline = block.timestamp + VOTING_PERIOD
     - status = Active
   - Emit ProposalSubmitted

2. **Cast Vote:**
   - Require proposal is Active
   - Require block.timestamp <= votingDeadline
   - Require voter hasn't voted yet on this proposal
   - Get voting power from SolarProject (voter's token balance)
   - Require voting power > 0 (must be token holder)
   - Mark hasVoted[proposalId][voter] = true
   - If support == true:
     - yesVotes += votingPower
   - Else:
     - noVotes += votingPower
   - Emit VoteCast

3. **Execute Proposal:**
   - Require proposal status is Active
   - Require block.timestamp > votingDeadline (voting period ended)
   - Get total token supply from SolarProject
   - Calculate if passed:
     - quorum = totalSupply \* QUORUM_PERCENTAGE / 100
     - passed = yesVotes > quorum
   - If passed:
     - Set status = Passed
     - Call revenueDistributor.withdrawMaintenance(projectId, amount, vendor)
     - Set executed = true
     - Set status = Executed
     - Emit FundsTransferred
   - Else:
     - Set status = Rejected
   - Emit ProposalExecuted

**Access Control:**

- submitProposal: Anyone
- castVote: Only token holders (voting power > 0)
- executeProposal: Anyone (after voting period)

**Integration Points:**

- Reads token balances from SolarProject.balanceOf()
- Reads total supply from SolarProject.getTotalShares()
- Calls RevenueDistributor.withdrawMaintenance() to transfer funds

**Example:**

Project has 1000 total tokens.
Maintenance reserve: $1,000

Proposal:

- Description: "Replace damaged inverter"
- Amount: $500
- Vendor: 0xVendorAddress

Voting:

- Investor A (500 tokens) votes YES → yesVotes = 500
- Investor B (300 tokens) votes YES → yesVotes = 800
- Investor C (200 tokens) votes NO → noVotes = 200

After 7 days:

- Total supply = 1000
- Quorum needed = 1000 \* 50% = 500
- yesVotes (800) > quorum (500) ✓ PASSED

Execution:

- Calls revenueDistributor.withdrawMaintenance(projectId, $500, vendor)
- Vendor receives $500 USDC
- Maintenance reserve reduced to $500

---

## Test: MaintenanceDAO.t.sol

**Location:** `test/unit/MaintenanceDAO.t.sol`

**Test Cases (Minimum 30):**

```solidity
// Setup
- Deploy all contracts
- Create and fund project with 3 investors
- Generate maintenance reserve (execute waterfall)

// Proposal Submission Tests
- ✅ Anyone can submit proposal
- ✅ Proposal ID increments
- ✅ Proposal details stored correctly
- ✅ Voting deadline set to 7 days
- ✅ Initial status is Active
- ✅ Cannot submit with zero vendor address
- ✅ Cannot submit amount > available reserve
- ✅ Emits ProposalSubmitted event

// Voting Tests
- ✅ Token holder can vote
- ✅ Voting power equals token balance
- ✅ YES vote increases yesVotes
- ✅ NO vote increases noVotes
- ✅ Cannot vote twice on same proposal
- ✅ Cannot vote with zero tokens
- ✅ Cannot vote after deadline
- ✅ Cannot vote on executed proposal
- ✅ Emits VoteCast event

// Voting Power Tests
- ✅ Investor with 500 tokens has 500 votes
- ✅ Investor with 100 tokens has 100 votes
- ✅ Non-token-holder has 0 votes
- ✅ Voting power reflects current balance

// Execution Tests (Passed)
- ✅ Cannot execute before deadline
- ✅ Can execute after deadline
- ✅ Proposal passes with >50% YES votes
- ✅ Funds transferred to vendor
- ✅ Maintenance reserve decreased
- ✅ Status changes to Executed
- ✅ Emits ProposalExecuted event
- ✅ Emits FundsTransferred event
- ✅ Cannot execute twice

// Execution Tests (Rejected)
- ✅ Proposal rejected with ≤50% YES votes
- ✅ Status changes to Rejected
- ✅ No funds transferred
- ✅ Vendor balance unchanged
- ✅ Maintenance reserve unchanged

// Quorum Tests
- ✅ Exactly 50% YES votes = rejected
- ✅ 51% YES votes = passed
- ✅ 100% YES votes = passed
- ✅ 0% YES votes = rejected

// Edge Cases
- ✅ No votes cast = rejected
- ✅ Only NO votes = rejected
- ✅ Multiple proposals active simultaneously
- ✅ Execute multiple proposals sequentially
- ✅ Insufficient reserve balance (should revert)
```

**Coverage Target:** >85%

---

# SECTION 8: INTEGRATION TESTS

**Location:** `test/integration/FullSystem.t.sol`

## Requirements

Test the complete system end-to-end with all contracts interacting.

**Test Cases:**

### Test 1: Happy Path - Complete Lifecycle

```solidity
function test_FullLifecycle_HappyPath() public {
    // 1. Setup: Deploy all contracts
    // 2. Host mints SBT
    // 3. Host creates project ($20,000 target, 120 months, 1000 shares)
    // 4. Three investors fund project:
    //    - Investor A: 500 shares ($10,000) = 50%
    //    - Investor B: 300 shares ($6,000) = 30%
    //    - Investor C: 200 shares ($4,000) = 20%
    // 5. Project reaches 100% funding
    // 6. LoanManager initializes loan ($200/month)
    //
    // Month 1:
    // 7. Host pays $200
    // 8. Oracle deposits $80 grid revenue
    // 9. Execute waterfall: $280 total
    //    - Dividend: $260.40 (93%)
    //    - Maintenance: $14.00 (5%)
    //    - Insurance: $5.60 (2%)
    // 10. Investor A claims dividends
    //     - Expected: $260.40 * 50% = $130.20
    // 11. Investor B claims dividends
    //     - Expected: $260.40 * 30% = $78.12
    // 12. Investor C claims dividends
    //     - Expected: $260.40 * 20% = $52.08
    //
    // Month 2:
    // 13. Host pays $200
    // 14. Oracle deposits $120 grid revenue
    // 15. Execute waterfall: $320 total
    //     - Dividend: $297.60 (93%)
    // 16. All investors claim month 2
    //
    // Assertions:
    // ✅ All USDC balances correct
    // ✅ Equity split at month 1 = ~1% host, 99% investors
    // ✅ Equity split at month 2 = ~2% host, 98% investors
    // ✅ Host reputation still 1000 (no default)
    // ✅ Project status = Active
}
```

### Test 2: Default Scenario

```solidity
function test_DefaultScenario() public {
    // 1. Setup: Project funded and active
    // 2. Month 1: Host pays on time
    // 3. Month 2: Host does NOT pay
    // 4. Warp time +31 days
    // 5. Anyone calls checkDefaultStatus() → returns true
    // 6. Keeper calls declareDefault()
    // 7. Assertions:
    //    ✅ Project status = Defaulted
    //    ✅ Host reputation = 800 (slashed -200)
    //    ✅ isDefaulted = true
    //    ✅ Cannot make further payments
    //    ✅ DefaultDeclared event emitted
    // 8. Trigger buyout
    // 9. Equity split at month 1: ~1% host, 99% investors
    // 10. Investors receive 99% of buyout amount pro-rata
    // 11. Host receives 1% of buyout amount
    // 12. All investor tokens burned
    // 13. Project status = BoughtOut
}
```

### Test 3: Multi-Month Accumulation

```solidity
function test_MultiMonthAccumulation() public {
    // 1. Setup: Project active
    // 2. Month 1-5: Host pays each month
    // 3. Oracle deposits revenue each month
    // 4. Execute waterfall each month
    // 5. Investor A does NOT claim for 5 months
    // 6. After month 5, Investor A claims all accumulated
    // 7. Assertions:
    //    ✅ Total claimed = sum of 5 months
    //    ✅ Single transaction pulls everything
    //    ✅ Gas cost is O(1) (doesn't scale with months)
}
```

### Test 4: Multiple Projects Simultaneously

```solidity
function test_MultipleProjects() public {
    // 1. Host A creates Project 1
    // 2. Host B creates Project 2
    // 3. Both projects get funded
    // 4. Both hosts make payments
    // 5. Revenue distributed separately
    // 6. Assertions:
    //    ✅ Dividends don't mix between projects
    //    ✅ Each project has isolated state
    //    ✅ Reputation tracks per host correctly
}
```

### Test 5: Buyout Mid-Term

```solidity
function test_BuyoutAtMonth60() public {
    // 1. Setup: Project active
    // 2. Fast-forward to month 60 (50% amortization)
    // 3. Host makes all 60 payments
    // 4. Host triggers buyout with $15,000 offer
    // 5. Assertions:
    //    ✅ Equity split = 50% host, 50% investors
    //    ✅ Host receives $7,500
    //    ✅ Investors receive $7,500 total (pro-rata)
    //    ✅ All investor tokens burned
    //    ✅ Project status = BoughtOut
}
```

### Test 6: Governance Proposal - Passed

```solidity
function test_GovernanceProposal_Passed() public {
    // 1. Setup: Project active with maintenance reserve
    // 2. Generate $1,000 in maintenance reserve (5% of $20,000)
    // 3. Submit repair proposal:
    //    - Description: "Replace inverter"
    //    - Amount: $500
    //    - Vendor: 0xVendorAddress
    // 4. Investors vote:
    //    - Investor A (500 tokens): YES
    //    - Investor B (300 tokens): YES
    //    - Investor C (200 tokens): NO
    // 5. Wait 7 days
    // 6. Execute proposal
    // 7. Assertions:
    //    ✅ Proposal status = Executed
    //    ✅ yesVotes = 800 (80%)
    //    ✅ noVotes = 200 (20%)
    //    ✅ Vendor received $500 USDC
    //    ✅ Maintenance reserve = $500 (reduced)
    //    ✅ ProposalExecuted event emitted
    //    ✅ FundsTransferred event emitted
}
```

### Test 7: Governance Proposal - Rejected

```solidity
function test_GovernanceProposal_Rejected() public {
    // 1. Setup: Same as Test 6
    // 2. Submit proposal for $500
    // 3. Investors vote:
    //    - Investor A (500 tokens): NO
    //    - Investor B (300 tokens): YES
    //    - Investor C (200 tokens): YES
    // 4. Wait 7 days
    // 5. Execute proposal
    // 6. Assertions:
    //    ✅ Proposal status = Rejected
    //    ✅ yesVotes = 500 (50% - not enough)
    //    ✅ noVotes = 500
    //    ✅ Vendor received $0
    //    ✅ Maintenance reserve unchanged ($1,000)
    //    ✅ No funds transferred
}
```

### Test 8: Multiple Proposals

```solidity
function test_MultipleProposals() public {
    // 1. Setup: Maintenance reserve = $1,000
    // 2. Submit Proposal 1: $300 for panel cleaning
    // 3. Submit Proposal 2: $400 for wiring repair
    // 4. Investors vote on both
    // 5. Execute both after deadline
    // 6. Assertions:
    //    ✅ Both can be active simultaneously
    //    ✅ Voting isolated per proposal
    //    ✅ Both can pass independently
    //    ✅ Total transferred = $700
    //    ✅ Maintenance reserve = $300
}
```

**Coverage Target:** All critical paths tested

---

# SECTION 8: DEPLOYMENT

## Deploy Script

**Location:** `script/Deploy.s.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/core/SolarProject.sol";
import "../src/core/LoanManager.sol";
import "../src/core/RevenueDistributor.sol";
import "../src/core/HostReputation.sol";
import "../src/mocks/MockGridOracle.sol";
import "../src/mocks/MockChainlinkKeeper.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDC
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed:", address(usdc));

        // 2. Deploy HostReputation
        HostReputation reputation = new HostReputation();
        console.log("HostReputation deployed:", address(reputation));

        // 3. Deploy SolarProject
        SolarProject solarProject = new SolarProject(address(usdc));
        console.log("SolarProject deployed:", address(solarProject));

        // 4. Deploy LoanManager
        LoanManager loanManager = new LoanManager(
            address(solarProject),
            address(usdc),
            address(reputation)
        );
        console.log("LoanManager deployed:", address(loanManager));

        // 5. Deploy RevenueDistributor
        RevenueDistributor distributor = new RevenueDistributor(
            address(solarProject),
            address(usdc)
        );
        console.log("RevenueDistributor deployed:", address(distributor));

        // 6. Deploy MaintenanceDAO
        MaintenanceDAO dao = new MaintenanceDAO(
            address(solarProject),
            address(distributor),
            address(usdc)
        );
        console.log("MaintenanceDAO deployed:", address(dao));

        // 7. Set RevenueDistributor in LoanManager
        loanManager.setRevenueDistributor(address(distributor));

        // 8. Set LoanManager in RevenueDistributor
        distributor.setLoanManager(address(loanManager));

        // 9. Grant MAINTAINER_ROLE to MaintenanceDAO (allows withdrawal from reserve)
        bytes32 maintainerRole = distributor.MAINTAINER_ROLE();
        distributor.grantRole(maintainerRole, address(dao));

        // 10. Grant SLASHER_ROLE to LoanManager
        bytes32 slasherRole = reputation.SLASHER_ROLE();
        reputation.grantRole(slasherRole, address(loanManager));

        // 11. Deploy MockGridOracle
        MockGridOracle oracle = new MockGridOracle(
            address(usdc),
            address(distributor)
        );
        console.log("MockGridOracle deployed:", address(oracle));

        // 12. Deploy MockChainlinkKeeper
        MockChainlinkKeeper keeper = new MockChainlinkKeeper(
            address(loanManager)
        );
        console.log("MockKeeper deployed:", address(keeper));

        vm.stopBroadcast();

        // Save addresses
        console.log("\n=== Deployment Complete ===");
        console.log("Network: Sepolia");
        console.log("Update .env with these addresses:");
        console.log("MOCK_USDC=", address(usdc));
        console.log("SOLAR_PROJECT=", address(solarProject));
        console.log("LOAN_MANAGER=", address(loanManager));
        console.log("REVENUE_DISTRIBUTOR=", address(distributor));
        console.log("HOST_REPUTATION=", address(reputation));
        console.log("MAINTENANCE_DAO=", address(dao));
        console.log("MOCK_GRID_ORACLE=", address(oracle));
        console.log("MOCK_KEEPER=", address(keeper));
    }
}
```

**Deploy Commands:**

```bash
# Load environment
source .env

# Deploy to Sepolia
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv

# Verify contracts individually (if needed)
forge verify-contract <ADDRESS> src/core/SolarProject.sol:SolarProject --chain sepolia --watch
```

---

## Mock Oracle Script

**Location:** `script/MockOracle.s.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockGridOracle.sol";

contract MockOracleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("MOCK_GRID_ORACLE");
        uint256 projectId = 1; // Update as needed

        MockGridOracle oracle = MockGridOracle(oracleAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Submit revenue every 60 seconds in a loop
        while (true) {
            console.log("Submitting grid revenue...");
            oracle.submitGridRevenue(projectId);
            console.log("Revenue submitted at:", block.timestamp);

            // Wait 60 seconds
            vm.sleep(60000); // 60 seconds in milliseconds
        }

        vm.stopBroadcast();
    }
}
```

**Run:**

```bash
# Run in background during demo
forge script script/MockOracle.s.sol:MockOracleScript --rpc-url $SEPOLIA_RPC_URL --broadcast &
```

---

# SECTION 9: FRONTEND MINIMAL

## Setup Instructions

Since you already have the Next.js frontend set up with Wagmi, we just need to add contract integration.

### Step 1: Copy Contract ABIs

```bash
# Create ABIs directory
mkdir -p frontend/src/contracts/abis

# Copy ABIs from Foundry artifacts
cp solar-share/out/SolarProject.sol/SolarProject.json frontend/src/contracts/abis/
cp solar-share/out/LoanManager.sol/LoanManager.json frontend/src/contracts/abis/
cp solar-share/out/RevenueDistributor.sol/RevenueDistributor.json frontend/src/contracts/abis/
cp solar-share/out/HostReputation.sol/HostReputation.json frontend/src/contracts/abis/
cp solar-share/out/MockUSDC.sol/MockUSDC.json frontend/src/contracts/abis/
```

### Step 2: Create Contract Addresses File

**Location:** `frontend/src/contracts/addresses.ts`

```typescript
export const contracts = {
  sepolia: {
    mockUSDC: "0x...", // From deployment
    solarProject: "0x...", // From deployment
    loanManager: "0x...", // From deployment
    revenueDistributor: "0x...", // From deployment
    hostReputation: "0x...", // From deployment
    mockGridOracle: "0x...", // From deployment
  },
} as const;
```

### Step 3: Create Custom Hooks

**Location:** `frontend/src/hooks/useContracts.ts`

```typescript
import { useReadContract, useWriteContract } from "wagmi";
import { contracts } from "@/contracts/addresses";
import SolarProjectABI from "@/contracts/abis/SolarProject.json";
import RevenueDistributorABI from "@/contracts/abis/RevenueDistributor.json";
import MockUSDABI from "@/contracts/abis/MockUSDC.json";

export function useProjectDetails(projectId: number) {
  return useReadContract({
    address: contracts.sepolia.solarProject,
    abi: SolarProjectABI.abi,
    functionName: "getProjectDetails",
    args: [BigInt(projectId)],
  });
}

export function useFundProject() {
  return useWriteContract();
}

export function useClaimDividends() {
  return useWriteContract();
}

export function useClaimableDividends(
  projectId: number,
  address: `0x${string}`,
) {
  return useReadContract({
    address: contracts.sepolia.revenueDistributor,
    abi: RevenueDistributorABI.abi,
    functionName: "getClaimableDividends",
    args: [BigInt(projectId), address],
  });
}

// Governance hooks
export function useProposal(proposalId: number) {
  return useReadContract({
    address: contracts.sepolia.maintenanceDAO,
    abi: MaintenanceDAOABI.abi,
    functionName: "getProposal",
    args: [BigInt(proposalId)],
  });
}

export function useVotingPower(projectId: number, address: `0x${string}`) {
  return useReadContract({
    address: contracts.sepolia.maintenanceDAO,
    abi: MaintenanceDAOABI.abi,
    functionName: "getVotingPower",
    args: [BigInt(projectId), address],
  });
}

export function useHasVoted(proposalId: number, address: `0x${string}`) {
  return useReadContract({
    address: contracts.sepolia.maintenanceDAO,
    abi: MaintenanceDAOABI.abi,
    functionName: "hasVotedOnProposal",
    args: [BigInt(proposalId), address],
  });
}

export function useSubmitProposal() {
  return useWriteContract();
}

export function useCastVote() {
  return useWriteContract();
}

export function useExecuteProposal() {
  return useWriteContract();
}
```

### Step 4: Update Project Detail Page

**Location:** `frontend/src/app/projects/[id]/page.tsx`

```typescript
'use client';

import { useParams } from 'next/navigation';
import { useAccount } from 'wagmi';
import { useProjectDetails, useClaimableDividends } from '@/hooks/useContracts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import InvestWidget from '@/components/InvestWidget';
import ClaimDividends from '@/components/ClaimDividends';

export default function ProjectDetailPage() {
  const params = useParams();
  const projectId = Number(params.id);
  const { address } = useAccount();

  const { data: project, isLoading } = useProjectDetails(projectId);
  const { data: claimable } = useClaimableDividends(projectId, address || '0x0');

  if (isLoading) return <div>Loading...</div>;

  return (
    <div className="container mx-auto px-8 py-12">
      <h1 className="text-4xl font-bold mb-8">Project #{projectId}</h1>

      <div className="grid md:grid-cols-2 gap-8">
        <div>
          <Card className="mb-6">
            <CardHeader>
              <CardTitle>Project Details</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex justify-between">
                  <span className="text-gray-500">Target Amount</span>
                  <span className="font-semibold">
                    ${(Number(project.targetAmount) / 1e6).toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Amount Raised</span>
                  <span className="font-semibold">
                    ${(Number(project.amountRaised) / 1e6).toLocaleString()}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Term</span>
                  <span className="font-semibold">
                    {Number(project.termMonths)} months
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-500">Status</span>
                  <span className="font-semibold">
                    {project.isFunded ? 'Active' : 'Funding'}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>

          {claimable && claimable > 0n && (
            <ClaimDividends projectId={projectId} />
          )}
        </div>

        <div>
          {!project.isFunded && (
            <InvestWidget projectId={projectId} />
          )}
        </div>
      </div>
    </div>
  );
}
```

### Step 5: Create Invest Widget Component

**Location:** `frontend/src/components/InvestWidget.tsx`

```typescript
'use client';

import { useState } from 'react';
import { useWriteContract, useAccount } from 'wagmi';
import { parseUnits } from 'viem';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { contracts } from '@/contracts/addresses';
import MockUSDABI from '@/contracts/abis/MockUSDC.json';
import SolarProjectABI from '@/contracts/abis/SolarProject.json';

export default function InvestWidget({ projectId }: { projectId: number }) {
  const [numShares, setNumShares] = useState('');
  const { writeContract, isPending } = useWriteContract();
  const { address } = useAccount();

  const handleApprove = async () => {
    const amount = parseUnits(numShares, 6); // USDC has 6 decimals

    writeContract({
      address: contracts.sepolia.mockUSDC,
      abi: MockUSDABI.abi,
      functionName: 'approve',
      args: [contracts.sepolia.solarProject, amount]
    });
  };

  const handleInvest = async () => {
    writeContract({
      address: contracts.sepolia.solarProject,
      abi: SolarProjectABI.abi,
      functionName: 'fundProject',
      args: [BigInt(projectId), BigInt(numShares)]
    });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Invest in This Project</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <label className="text-sm font-medium mb-2 block">
            Number of Shares
          </label>
          <Input
            type="number"
            value={numShares}
            onChange={(e) => setNumShares(e.target.value)}
            placeholder="Enter number of shares"
          />
        </div>

        <div className="space-y-2">
          <Button
            onClick={handleApprove}
            disabled={isPending || !numShares}
            className="w-full"
          >
            1. Approve USDC
          </Button>

          <Button
            onClick={handleInvest}
            disabled={isPending || !numShares}
            className="w-full"
          >
            2. Invest
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
```

### Step 6: Create Claim Dividends Component

**Location:** `frontend/src/components/ClaimDividends.tsx`

```typescript
'use client';

import { useWriteContract, useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useClaimableDividends } from '@/hooks/useContracts';
import { contracts } from '@/contracts/addresses';
import RevenueDistributorABI from '@/contracts/abis/RevenueDistributor.json';

export default function ClaimDividends({ projectId }: { projectId: number }) {
  const { address } = useAccount();
  const { data: claimable } = useClaimableDividends(projectId, address!);
  const { writeContract, isPending } = useWriteContract();

  const handleClaim = () => {
    writeContract({
      address: contracts.sepolia.revenueDistributor,
      abi: RevenueDistributorABI.abi,
      functionName: 'claimDividends',
      args: [BigInt(projectId)]
    });
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Claimable Dividends</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-bold text-green-600 mb-4">
          ${formatUnits(claimable || 0n, 6)} USDC
        </div>
        <Button
          onClick={handleClaim}
          disabled={isPending || !claimable || claimable === 0n}
          className="w-full"
        >
          {isPending ? 'Claiming...' : 'Claim Now'}
        </Button>
      </CardContent>
    </Card>
  );
}
```

---

# SECTION 10: TESTING COMMANDS

## Run All Tests

```bash
# Run all unit tests
forge test

# Run specific test file
forge test --match-path test/unit/SolarProject.t.sol

# Run with gas reporting
forge test --gas-report

# Run with verbosity (see console.logs)
forge test -vvv

# Run integration tests only
forge test --match-path test/integration/FullSystem.t.sol

# Generate coverage report
forge coverage

# Generate detailed coverage report
forge coverage --report lcov
```

## Build Commands

```bash
# Compile contracts
forge build

# Clean and rebuild
forge clean && forge build

# Format code
forge fmt
```

---

# SECTION 11: DEMO SCRIPT

## DEMO.md

Create `DEMO.md` file:

````markdown
# Solar Share Demo Script

## Pre-Demo Setup

1. **Deploy all contracts to Sepolia**
   ```bash
   forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
   ```
````

2. **Fund test wallets with Sepolia ETH**
   - Host wallet: Get from https://sepoliafaucet.com
   - Investor 1-3 wallets: Get ETH for gas

3. **Mint MockUSDC to all wallets**

   ```bash
   cast send $MOCK_USDC "mint(address,uint256)" <WALLET> 100000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

4. **Start mock oracle (background)**
   ```bash
   forge script script/MockOracle.s.sol:MockOracleScript --rpc-url $SEPOLIA_RPC_URL --broadcast &
   ```

## Demo Flow

### Part 1: Project Creation & Funding (5 min)

**Host (Wallet 1):**

1. **Mint SBT (if first project)**
   - Call `HostReputation.mintSBT(hostAddress)`
   - Check reputation = 1000

2. **Create Project**
   - Target: $20,000
   - Term: 120 months
   - Shares: 1000
   - Call `SolarProject.initializeProject(20000000000, 120, 1000)`
   - Note projectId (should be 1)

**Investors:**

3. **Investor A funds 500 shares ($10,000)**
   - Approve USDC: `MockUSDC.approve(SolarProject, 10000000000)`
   - Fund: `SolarProject.fundProject(1, 500)`

4. **Investor B funds 300 shares ($6,000)**
   - Same process

5. **Investor C funds 200 shares ($4,000)**
   - Same process

6. **Check project status**
   - Call `SolarProject.getProjectDetails(1)`
   - Verify: isFunded = true, status = Active

### Part 2: Loan Initialization (2 min)

**LoanManager:**

7. **Initialize loan**
   - Call `LoanManager.initializeLoan(1, 200000000, 120)`
   - Monthly payment: $200
   - Term: 120 months

### Part 3: Month 1 - Revenue Flow (10 min)

**Host:**

8. **Make monthly payment**
   - Approve: `MockUSDC.approve(LoanManager, 200000000)`
   - Pay: `LoanManager.payMonthlyInstallment(1)`

**Oracle (automatic):**

9. **Grid revenue deposited**
   - MockOracle automatically calls `RevenueDistributor.depositGridRevenue(1, ~80000000)`
   - Random between $20-$150

**Anyone:**

10. **Execute waterfall**
    - Call `RevenueDistributor.executeWaterfall(1)`
    - Check pools:
      - Dividend: $260.40 (93%)
      - Maintenance: $14.00 (5%)
      - Insurance: $5.60 (2%)

**Investors:**

11. **Claim dividends**
    - Investor A: `RevenueDistributor.claimDividends(1)`
      - Should receive ~$130.20 (50% of $260.40)
    - Investor B: Claims ~$78.12 (30%)
    - Investor C: Claims ~$52.08 (20%)

12. **Verify balances**
    - Check each investor's USDC balance increased

### Part 4: Default Scenario (Optional, 5 min)

**Simulate Default:**

13. **Skip month 2 payment**
    - Host does NOT call payMonthlyInstallment
    - Wait 31 days (or use `vm.warp` in test)

14. **Check default status**
    - Call `LoanManager.checkDefaultStatus(1)`
    - Returns: true

15. **Declare default**
    - Anyone calls `LoanManager.declareDefault(1)`
    - Check events: DefaultDeclared emitted

16. **Check reputation**
    - Call `HostReputation.getScore(hostAddress)`
    - Should be 800 (slashed -200)

17. **Trigger buyout**
    - Call `SolarProject.triggerBuyout(1, 15000000000)`
    - Equity split at month 1: ~1% host, 99% investors
    - Host receives ~$150
    - Investors receive ~$14,850 pro-rata

### Part 5: Frontend Demo (5 min)

**Browse Projects:**

18. Navigate to `/explore`
    - See Project #1 listed
    - Click to view details

**Project Details:**

19. View project page
    - See all project details
    - Funding progress
    - Investment widget (if still funding)

**Investor Dashboard:**

20. Navigate to `/dashboard`
    - See portfolio
    - Total invested
    - Claimable dividends
    - Click "Claim" button

**Host Dashboard:**

21. Navigate to `/host/dashboard`
    - See reputation score
    - Loan status
    - Next payment due
    - Click "Pay Installment"

### Part 6: Governance Demo (5 min)

**Governance Workflow:**

22. **Navigate to `/governance`**
    - See active proposals page

23. **Create a repair proposal (Investor A):**
    - Click "Create Proposal"
    - Description: "Replace damaged inverter"
    - Amount: $500
    - Vendor: 0xVendorWallet
    - Submit proposal

24. **Investors vote on proposal:**
    - Investor A (500 tokens): Votes YES
    - Investor B (300 tokens): Votes YES
    - Investor C (200 tokens): Votes NO
    - Current tally: 800 YES / 200 NO

25. **Wait for voting period to end (7 days in production, instant in test)**

26. **Execute passed proposal:**
    - Anyone clicks "Execute Proposal"
    - Check events: ProposalExecuted, FundsTransferred
    - Verify vendor received $500 USDC
    - Maintenance reserve reduced by $500

## Expected Results

- ✅ Project created and funded
- ✅ Loan payments tracked correctly
- ✅ Revenue distributed 93/5/2
- ✅ Investors receive proportional dividends
- ✅ Default detection works
- ✅ Reputation slashing works
- ✅ Buyout calculation accurate
- ✅ Frontend interactions smooth
- ✅ All transactions on Sepolia Etherscan

## Etherscan Links

Prepare these beforehand:

- SolarProject: https://sepolia.etherscan.io/address/0x...
- LoanManager: https://sepolia.etherscan.io/address/0x...
- RevenueDistributor: https://sepolia.etherscan.io/address/0x...
- HostReputation: https://sepolia.etherscan.io/address/0x...

## Troubleshooting

**If transaction fails:**

- Check USDC approval
- Check gas balance
- Verify contract addresses in .env

**If oracle not working:**

- Restart MockOracle script
- Check oracle has USDC to deposit
- Verify oracle address correct

**If frontend not updating:**

- Refresh page
- Check wallet connection
- Verify contract addresses in addresses.ts

```

---

# FINAL CHECKLIST

## Smart Contracts
- [ ] MockUSDC.sol implemented and tested
- [ ] SolarProject.sol implemented and tested (>85% coverage)
- [ ] LoanManager.sol implemented and tested (>85% coverage)
- [ ] RevenueDistributor.sol implemented and tested (>85% coverage)
- [ ] HostReputation.sol implemented and tested (>85% coverage)
- [ ] MaintenanceDAO.sol implemented and tested (>85% coverage)
- [ ] MockGridOracle.sol implemented
- [ ] MockChainlinkKeeper.sol implemented
- [ ] Integration tests complete
- [ ] All tests passing

## Deployment
- [ ] Deploy script created
- [ ] All contracts deployed to Sepolia
- [ ] All contracts verified on Etherscan
- [ ] Contract addresses saved to .env
- [ ] Mock oracle script running

## Frontend
- [ ] Contract ABIs copied
- [ ] Contract addresses configured
- [ ] Custom hooks created
- [ ] InvestWidget component working
- [ ] ClaimDividends component working
- [ ] Governance page complete
- [ ] ProposalCard component working
- [ ] CreateProposal component working
- [ ] Project detail page complete
- [ ] Dashboard pages complete
- [ ] Frontend deployed to Vercel

## Documentation
- [ ] README.md with overview
- [ ] ARCHITECTURE.md with contract details
- [ ] DEMO.md with demo script
- [ ] All functions documented
- [ ] Video walkthrough recorded

## Testing
- [ ] Unit tests >80% coverage
- [ ] Integration tests passing
- [ ] Gas optimization verified
- [ ] Security review done
- [ ] Edge cases covered

---

# SUCCESS METRICS

By the end, you will have:

✅ **8 Smart Contracts** deployed to Sepolia (5 core + 3 mocks)
✅ **600+ lines of tests** with >80% coverage
✅ **Working frontend** for investment, dividend claiming, and governance
✅ **Complete documentation** and demo script
✅ **Video walkthrough** showing end-to-end flow
✅ **Production-ready PoC** suitable for blockchain course assessment

---

# APPENDIX: QUICK REFERENCE

## Key Formulas

**Equity Split (Amortization):**
```

hostPercent = (currentMonth \* 100) / termMonths
investorPercent = 100 - hostPercent

```

**Waterfall Split:**
```

dividendAmount = totalRevenue _ 93 / 100
maintenanceAmount = totalRevenue _ 5 / 100
insuranceAmount = totalRevenue \* 2 / 100

```

**Pull-Based Dividends:**
```

dividendPerShare += (dividendAmount _ 1e18) / totalShares
claimable = (shares _ dividendPerShare / 1e18) - alreadyClaimed

```

## Important Addresses (Update After Deployment)

```

MockUSDC: 0x...
SolarProject: 0x...
LoanManager: 0x...
RevenueDistributor: 0x...
HostReputation: 0x...
MaintenanceDAO: 0x...
MockGridOracle: 0x...
MockKeeper: 0x...

````

## Useful Commands

```bash
# Test
forge test -vvv
forge coverage

# Deploy
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Verify single contract
forge verify-contract <ADDRESS> src/core/SolarProject.sol:SolarProject --chain sepolia

# Format
forge fmt

# Build
forge build
````

---

**END OF CLAUDE.MD**

This file contains everything needed to implement Solar Share using Foundry and Claude Code. Copy the entire file and paste it to Claude Code to begin implementation.
