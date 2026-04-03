// This code is run by the decentralized Chainlink nodes off-chain

const zipCode = args[0]; // Passed from the smart contract

// Example: Calling OpenWeatherMap (or any weather API we choose)
const url = `https://api.openweathermap.org/data/2.5/weather?zip=${zipCode},us&appid=${secrets.weatherApiKey}`;

const weatherRequest = Functions.makeHttpRequest({
  url: url,
  method: "GET",
});

const weatherResponse = await weatherRequest;

if (weatherResponse.error) {
  throw Error("Weather API request failed");
}

// In a real historical API, you'd calculate days of rain. 
// For this prototype, let's say the API returns a JSON object where 
// weatherResponse.data.rain_days_last_month = 22
const rainyDays = weatherResponse.data.rain_days_last_month || 0;

// Chainlink requires the response to be encoded as bytes
// Functions.encodeUint256 turns our JavaScript number into Solidity bytes
return Functions.encodeUint256(Math.round(rainyDays));