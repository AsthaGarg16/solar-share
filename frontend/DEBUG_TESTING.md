# Testing Default Flow in UI

## Quick Start

### 1. **Start Anvil** (in a terminal)
```bash
cd backend
anvil
```

### 2. **Deploy Contracts**
```bash
forge script script/Deploy.s.sol:DeployScript --fork-url http://127.0.0.1:8545 --broadcast
```

### 3. **Start Frontend**
```bash
cd frontend
npm run dev
```

### 4. **Set Environment Variables**
Create/update `frontend/.env.local`:
```env
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545
NEXT_PUBLIC_CHAIN_ID=31337
```

### 5. **Access Debug Panel**
Navigate to:
```
http://localhost:3000/debug
```

---

## Test Flow: Default Scenario

### Scenario: Host doesn't pay for 15 days → Weather check → Declare default

#### Step 1: Create & Fund Project (One Time)
1. Go to `/explore`
2. Host creates project: $20,000, 120 months, 1000 shares
3. Investors fund the project (need USDC - get from faucet)
4. Project should reach 100% funding

#### Step 2: Initialize Loan (One Time)
1. LoanManager initializes with $200/month payment
2. Host's first payment is due in 30 days

#### Step 3: Skip Time (Simulate Non-Payment)
1. Go to `/debug`
2. Set **Project ID**: `1`
3. Set **Days to Skip**: `15`
4. Click **"Skip 15 Days"**
   - This simulates 15 days passing
   - Host has NOT made payment (deadline is 30 days, we're at day 15)
   - ✅ Time is now: Day 15 (still within grace period)

#### Step 4: Skip More Time (Cross Default Threshold)
1. Set **Days to Skip**: `20` (now at day 35, past 30-day deadline)
2. Click **"Skip 20 Days"** again
   - Next payment due was at: Day 30
   - Current time is now: Day 35
   - ✅ Host is NOW in default

#### Step 5: Check Weather
1. Click **"Check Weather"**
2. UI shows:
   - 🌧️ Raining = OK (host can't generate power)
   - ☀️ Not Raining = **DEFAULT CONFIRMED** 🔴
3. Weather oracle simulates random rainfall
   - If raining: Host has excuse, no automatic default
   - If not raining: Host must pay, NOT paying = default

#### Step 6: Check Default Status
1. Click **"Check Default Status"**
2. UI should show:
   - ✅ Status: **🔴 DEFAULT - True**
3. This means:
   - `checkDefaultStatus(1)` returned `true`
   - Host is overdue on payment
   - Weather doesn't excuse them

#### Step 7: Declare Default
1. Click **"Declare Default"**
2. This transaction:
   - ✅ Updates project status to `DEFAULTED`
   - ✅ Slashes host reputation (-200 points)
   - ✅ Emits `DefaultDeclared` event
3. Confirmation message appears

#### Step 8: Verify Default Results
1. Go to **Host Dashboard** (`/host/dashboard`)
   - Reputation should be: 800 (was 1000, -200 for default)
   - Status should show: ⚠️ DEFAULTED

2. Go to **Project Details** (`/projects/1`)
   - Status should show: ⚠️ DEFAULTED
   - May trigger automatic buyout offer

---

## Understanding the Logic

### Default = No Payment + No Weather Excuse

```
if (block.timestamp > nextPaymentDue) AND (NOT raining) {
  → Can declare default
} else {
  → Cannot declare (grace period or weather excuse)
}
```

### Weather Oracle Role

```solidity
// Simulated weather data
if (isRaining) {
  // Solar panels don't generate power
  // Host revenue is $0
  // Can't pay from non-existent revenue
  → Default is EXCUSED (no slashing)
} else {
  // Good weather, should be generating power
  // If no payment received
  → True default (reputation slashed)
}
```

### Equity Split at Default

After declaring default, you can trigger buyout:
- **Month 1 (very early)**: Host gets ~0%, Investors get ~100%
- **Month 30 (mid-term)**: Host gets ~25%, Investors get ~75%
- **Month 60 (half-way)**: Host gets ~50%, Investors get ~50%

---

## Troubleshooting

### "Cannot skip time" error

**Problem**: API endpoint returns 403
**Solution**: 
- Check `NODE_ENV=development` in frontend
- Verify `.env.local` has `NEXT_PUBLIC_RPC_URL`
- Restart frontend: `npm run dev`

### "Smart contract revert: not in default"

**Problem**: Declare Default button says "Host must be in default status first"
**Solution**:
1. Click "Check Default Status" first
2. Verify it shows: **🔴 TRUE**
3. If FALSE:
   - Go back and skip more time
   - Currently at: Day X (check console)
   - Need to be past: Day 30 (initial grace period)

### Weather oracle always shows "raining"

**Problem**: Can't trigger default because weather excuse is active
**Solution**: This is by design! The weather oracle adds realism:
- Wait and check again (simulated weather changes)
- Or deploy with different mock weather settings
- Check `MockWeatherOracle.sol` to adjust rainfall probability

### Project not showing up in `/debug`

**Problem**: Can't find project ID
**Solution**:
```bash
# Check deployments file
cat backend/deployments/31337.json

# Verify project exists
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
  "projectCount()(uint256)" \
  --rpc-url http://127.0.0.1:8545
```

---

## Advanced: CLI Testing (Alternative to UI)

If you want to use CLI instead of UI:

```bash
# Load addresses
source .env.local
LOAN_MANAGER=$(jq -r '.loanManager' backend/deployments/31337.json)
RPC="http://127.0.0.1:8545"

# Skip 35 days
cast rpc anvil_increaseTime 3024000 --rpc-url $RPC
cast rpc anvil_mine --rpc-url $RPC

# Check default status
cast call $LOAN_MANAGER "checkDefaultStatus(uint256)(bool)" 1 --rpc-url $RPC

# Declare default (must have proper private key)
cast send $LOAN_MANAGER "declareDefault(uint256)" 1 \
  --rpc-url $RPC \
  --private-key <YOUR_PRIVATE_KEY>
```

---

## Demo for Instructor

**Flow**: 
1. Open `/debug` panel
2. Show time-skipping functionality
3. Check weather oracle status
4. Declare default
5. Show host reputation decreased
6. Show project status changed to DEFAULTED

This demonstrates the trustless, automated default detection system! 🔴✅
