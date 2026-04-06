// args[0] = Physical Meter ID (e.g., "METER_123")
const meterId = args[0];
const GRID_PRICE_PER_KWH = 0.20; // Assume $0.20 per kWh

if (!meterId) {
  throw Error("Missing Solar Meter ID argument");
}

// 1. Fetch data from the Monitoring Platform
const url = `https://postman-echo.com/get?meter=${meterId}`;
const apiResponse = await Functions.makeHttpRequest({ url });

if (apiResponse.error) {
  throw Error("Grid API Connectivity Failed");
}

// 2. Logic: High vs Low Production Simulation
let simulatedKwh = meterId.startsWith('0') ? 50 : 450;

// 3. Calculate Revenue (In USDC 6-decimal format)
// Formula: kWh * Price * 10^6 
const revenueAmount = Math.floor(simulatedKwh * GRID_PRICE_PER_KWH * 1_000_000);

console.log(`Meter ${meterId}: ${simulatedKwh} kWh produced. Revenue: $${revenueAmount / 1e6} USDC`);

// 4. IMPORTANT: Use encodeUint256 for multiple values
// We combine them into a single buffer that Solidity decodes as (uint256, uint256)
return Buffer.concat([
  Functions.encodeUint256(simulatedKwh),
  Functions.encodeUint256(revenueAmount)
]);