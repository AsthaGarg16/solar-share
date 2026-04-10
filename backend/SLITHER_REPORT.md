# Slither Static Analysis Report — Solar Share Core Contracts

**Tool:** Slither v0.11.5
**Date:** 2026-04-10
**Scope:** `backend/src/core/` (5 contracts)
**Solc:** 0.8.20
**Total findings:** 69 (across core contracts + transitive OZ library references)

---

## Summary

| Severity       | Count (all) | Count (src/core only) |
|----------------|-------------|------------------------|
| High           | 1           | 0 (OZ lib false positive) |
| Medium         | 14          | 5 (3 reentrancy, 1 divide-before-multiply, 1 unused-return) |
| Low            | 21          | 20 |
| Informational  | 31          | 18 |
| Optimization   | 2           | 2 |

> Note: The single **High** finding (`incorrect-exp`) is in `lib/openzeppelin-contracts/Math.sol` — it is a known Slither false positive on OpenZeppelin's intentional use of `^` as bitwise-XOR (not exponentiation) in a bit-manipulation algorithm. It does **not** affect Solar Share code.

---

## HIGH Severity

### H-1 — `incorrect-exp` in OZ Math.mulDiv (FALSE POSITIVE)
**File:** `lib/openzeppelin-contracts/contracts/utils/math/Math.sol:116`
**Description:** Slither flags `(3 * denominator) ^ 2` as incorrect exponentiation. This is a known false positive — OpenZeppelin intentionally uses `^` as bitwise XOR here as part of a modular inverse algorithm.
**Impact on Solar Share:** None. This code is never called by Solar Share contracts.
**Action:** No fix required.

---

## MEDIUM Severity (src/core findings)

### M-1 — Reentrancy in `SolarProject.fundProject` (no-eth)
**File:** `src/core/SolarProject.sol:144-164`
**Description:** `_mint()` is called before `USDC.safeTransferFrom()`. The ERC-1155 `_mint` triggers the `onERC1155Received` callback on the recipient, which could re-enter `fundProject` before the USDC transfer and state update complete. State variable `project.isFunded` is written after the external call.
```
_mint(msg.sender, projectId, numShares, "")         ← external callback here
USDC.safeTransferFrom(msg.sender, address(this), amount)
project.isFunded = true                              ← state written too late
```
**Risk:** A malicious ERC-1155 receiver could re-enter to mint shares without paying.
**Fix:** Apply checks-effects-interactions: update `project.sharesSold`, `project.amountRaised`, and `project.isFunded` **before** calling `_mint` and `safeTransferFrom`. Alternatively, add `ReentrancyGuard`.

---

### M-2 — Reentrancy in `LoanManager.payMonthlyInstallment` (no-eth)
**File:** `src/core/LoanManager.sol:154-185`
**Description:** `USDC.safeTransferFrom` is called, then loan state (`currentMonth`, `totalPaid`, `nextPaymentDue`) is updated. A malicious USDC token could re-enter before state is updated, allowing duplicate payments.
**Risk:** Overpayment / state corruption if USDC were non-standard.
**Fix:** Update all loan state variables before the external USDC transfer, or add `ReentrancyGuard`.

---

### M-3 — Reentrancy in `SolarProject.triggerBuyout` (no-eth)
**File:** `src/core/SolarProject.sol:166-193`
**Description:** `USDC.safeTransferFrom` is called before project status is updated to `BoughtOut`. A re-entrant call could re-trigger the buyout.
**Fix:** Set `project.status = ProjectStatus.BoughtOut` and `project.isBoughtOut = true` before any external calls.

---

### M-4 — Divide-before-multiply in `RevenueDistributor._executeWaterfallInternal`
**File:** `src/core/RevenueDistributor.sol:120,130`
**Description:**
```solidity
dividendAmount = (total * DIVIDEND_PERCENTAGE) / 100;          // division
pool.dividendPerShare += (dividendAmount * PRECISION) / totalShares;  // multiply on result
```
Integer division truncates `dividendAmount` before it is multiplied by `PRECISION`, introducing systematic rounding loss in `dividendPerShare`.
**Fix:** Reorder to multiply before dividing:
```solidity
pool.dividendPerShare += (total * DIVIDEND_PERCENTAGE * PRECISION) / (100 * totalShares);
```

---

### M-5 — Unused return value in `LoanManager.payMonthlyInstallment`
**File:** `src/core/LoanManager.sol:174`
**Description:** The return value of `USDC.approve(address(revenueDistributor), payment)` is ignored. If the approval silently fails (non-reverting ERC-20), the subsequent transfer by the distributor will fail in a confusing way.
**Fix:** Use `SafeERC20.forceApprove` or check the return value with `require`.

---

## LOW Severity (src/core findings)

### L-1 — Missing zero-address checks in setters
**Files:**
- `RevenueDistributor.setLoanManager` (`sol:72`)
- `RevenueDistributor.setGridOracle` (`sol:76`)

**Description:** No `require(addr != address(0))` guards on admin setter functions. Setting these to zero address would permanently brick revenue distribution.
**Fix:** Add `require(_loanManager != address(0), "zero address")` guards.

---

### L-2 — Reentrancy (benign) in deposit functions
**Files:**
- `RevenueDistributor.depositGridRevenue` (sol:84)
- `RevenueDistributor.depositHostPayment` (sol:95)
- `SolarProject.triggerBuyout` (sol:166)

**Description:** State is written after external ERC-20 transfer calls. Slither classifies these as "benign" reentrancy (no direct ETH). No immediate exploit vector with a standard ERC-20, but the pattern is fragile.
**Fix:** Add `ReentrancyGuard` to all state-mutating public functions.

---

### L-3 — Reentrancy (events) — events emitted after external calls
**Files:** Multiple functions across `SolarProject`, `LoanManager`, `RevenueDistributor`, `MaintenanceDAO`, `HostReputation`
**Description:** Events are emitted after external calls, meaning logs could be emitted in an inconsistent state. This is not exploitable on its own but violates CEI (Checks-Effects-Interactions).
**Fix:** Move event emissions before external calls, or add `ReentrancyGuard`.

---

### L-4 — Block timestamp dependence
**Files:**
- `LoanManager.checkDefaultStatus` (sol:191)
- `LoanManager.declareDefault` (sol:199)
- `LoanManager.payMonthlyInstallment` (sol:179)
- `MaintenanceDAO.castVote` (sol:159)
- `MaintenanceDAO.executeProposal` (sol:184)

**Description:** Logic relies on `block.timestamp` for payment deadlines and voting deadlines. Miners/validators can manipulate timestamps by a small amount (~15 seconds on PoS), but all comparisons use 30-day or 7-day windows, making this practically negligible.
**Risk:** Minimal at current window sizes.
**Action:** Acceptable risk for a PoC; document the assumption. For production, consider Chainlink Time-lock or block-number-based expiry.

---

## INFORMATIONAL

### I-1 — Multiple Solidity pragma versions
**Description:** Three different `pragma` constraints (`^0.8.0`, `^0.8.1`, `^0.8.20`) across source and library files. The core contracts consistently use `^0.8.20`.
**Fix:** No action needed for core contracts; OZ library versions are fixed.

---

### I-2 — `solc-version` — known issues in ^0.8.20
**Description:** Three low-severity compiler bugs listed for `^0.8.20`: `VerbatimInvalidDeduplication`, `FullInlinerNonExpressionSplitArgumentEvaluationOrder`, `MissingSideEffectsOnSelectorAccess`. None affect typical ERC-20/ERC-1155/ERC-721 patterns.
**Fix:** Pin to `pragma solidity 0.8.20` (exact) instead of `^0.8.20` for production deploys.

---

### I-3 — `missing-inheritance`: `HostReputation` does not inherit `IHostReputation`
**File:** `src/core/HostReputation.sol:12`
**Description:** `HostReputation` implements all methods of `IHostReputation` but does not explicitly declare `is IHostReputation`. The compiler will not enforce interface compliance.
**Fix:**
```solidity
contract HostReputation is ERC721, AccessControl, IHostReputation {
```

---

### I-4 — Naming convention violations (non-mixedCase immutables/parameters)
**Files:** `LoanManager`, `MaintenanceDAO`, `RevenueDistributor`, `SolarProject`
**Description:** Immutable-style contract references (`SOLAR_PROJECT`, `HOST_REPUTATION`, `USDC`, etc.) are declared as `immutable` or regular variables but named in `UPPER_SNAKE_CASE`. Slither expects `mixedCase` for variables. Constant state variables conventionally use `UPPER_SNAKE_CASE`, which is correct — Slither produces false positives here when `immutable` is involved.
**Fix:** Either rename to `mixedCase` or add `// slither-disable-next-line naming-convention` where intentional.

---

## OPTIMIZATION

### O-1 — `LoanManager.gridOracle` and `LoanManager.weatherOracle` should be `immutable`
**File:** `src/core/LoanManager.sol:73-74`
**Description:** These state variables are set only in the constructor but not declared `immutable`, costing an extra SLOAD per access (~2100 gas cold vs ~100 gas for immutable).
**Fix:**
```solidity
address public immutable gridOracle;
address public immutable weatherOracle;
```

---

## Recommendations Summary

| Priority | Finding | Contract | Fix |
|----------|---------|----------|-----|
| High (fix before audit) | M-1: Reentrancy in `fundProject` | SolarProject | CEI order + ReentrancyGuard |
| High (fix before audit) | M-2: Reentrancy in `payMonthlyInstallment` | LoanManager | CEI order + ReentrancyGuard |
| High (fix before audit) | M-3: Reentrancy in `triggerBuyout` | SolarProject | Set status before external calls |
| Medium | M-4: Divide-before-multiply in waterfall | RevenueDistributor | Reorder arithmetic |
| Medium | M-5: Ignored `approve` return | LoanManager | Use `forceApprove` |
| Low | L-1: Missing zero-address checks | RevenueDistributor | Add `require` guards |
| Low | L-2/L-3: CEI violations / benign reentrancy | All | Add `ReentrancyGuard` |
| Low | L-4: Timestamp dependence | LoanManager, MaintenanceDAO | Document + acceptable for PoC |
| Info | I-3: Missing interface inheritance | HostReputation | Add `is IHostReputation` |
| Optimization | O-1: Non-immutable oracles | LoanManager | Declare `immutable` |

---

## False Positives (can be suppressed)

- **H-1** (`incorrect-exp` in `Math.sol`) — OZ internal bit manipulation, not exponentiation
- **Medium** `divide-before-multiply` findings in `Math.sol` — intentional OZ algorithm
- **I-4** naming-convention on `UPPER_SNAKE_CASE` immutables — idiomatic Solidity, Slither false positive

To suppress in Slither CLI:
```bash
slither src/core/ --exclude incorrect-exp,naming-convention --filter-paths "lib/"
```

---

## How to Re-run

```bash
cd backend/

# Quick re-run (text output)
slither src/core/ --foundry-compile-all --filter-paths "lib/"

# JSON output
slither src/core/ --foundry-compile-all --json slither-output.json

# Exclude known false positives and library noise
slither src/core/ --foundry-compile-all \
  --filter-paths "lib/" \
  --exclude incorrect-exp,naming-convention,solc-version,pragma
```
