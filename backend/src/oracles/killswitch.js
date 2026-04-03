// This script is executed off-chain by Chainlink Functions nodes.

// 1. Extract the hardware ID passed from the smart contract (args[0])
const inverterId = args[0]; 

if (!inverterId) {
  throw Error("Missing hardware API ID argument");
}

// 2. Define the secure API endpoint for the solar manufacturer (e.g., Enphase/Tesla)
// This is a placeholder URL for the prototype.
const apiUrl = `https://api.solar-manufacturer.com/v1/inverters/${inverterId}/export-mode`;

// 3. Make the HTTP POST request to change the hardware setting
console.log(`Sending killswitch command to inverter: ${inverterId}`);

const apiResponse = await Functions.makeHttpRequest({
  url: apiUrl,
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    // Chainlink Functions securely injects API keys so they are never exposed on-chain
    "Authorization": `Bearer ${secrets.solarApiKey}` 
  },
  data: {
    // The command to force the solar panel to dump all energy into the municipal grid
    "mode": "100_PERCENT_GRID_EXPORT",
    "lock_user_controls": true
  }
});

// 4. Handle the response
if (apiResponse.error) {
  console.error("API Request Failed:", apiResponse.error);
  throw Error("Failed to trigger IoT Killswitch: " + apiResponse.error.message);
}

// 5. If successful, return a hex-encoded success message back to the smart contract
console.log("Killswitch activated successfully.");
return Functions.encodeString("KILLSWITCH_ACTIVATED");