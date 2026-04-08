// args[0] = The Hardware ID or Project ID passed from IoTSolarOracle.sol
const hardwareId = args[0]; 

if (!hardwareId) {
  throw Error("Missing hardware ID argument");
}

/**
 * 1. THE API CALL
 * We use Postman Echo to simulate a real-world hardware endpoint.
 * In a production environment, this would be your inverter's API:
 * https://api.enphase.com/v1/systems/${hardwareId}/lock_controls
 */
const apiUrl = `https://postman-echo.com/post`;

const apiResponse = await Functions.makeHttpRequest({
  url: apiUrl,
  method: "POST",
  headers: { "Content-Type": "application/json" },
  data: {
    "system_id": hardwareId,
    "action": "FORCE_GRID_EXPORT", // Forces solar power to grid, bypassing local use
    "user_lock": true              // Prevents the host from manually turning it back on
  }
});

// 2. ERROR HANDLING
if (apiResponse.error) {
  throw Error("IoT Hardware Communication Failed");
}

/**
 * 3. RETURN TO SOLIDITY
 * We return a simple uint256 (1 for success). 
 * Using numbers instead of strings saves significant gas during the callback!
 */
console.log(`Killswitch successful for Hardware: ${hardwareId}`);
return Functions.encodeUint256(1);