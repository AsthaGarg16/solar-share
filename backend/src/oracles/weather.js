// args[0] = Zip Code (e.g., "90210")
const zipCode = args[0]; 

if (!zipCode) {
  throw Error("Zip code argument is missing");
}

/**
 * 1. API CALL
 * We use Postman Echo to simulate a weather API response. 
 * In production, you would swap this for:
 * https://api.weatherapi.com/v1/history.json?key=YOUR_KEY&q=${zipCode}&dt=${lastMonth}
 */
const url = `https://postman-echo.com/get?zip=${zipCode}&type=weather_history`;

const apiResponse = await Functions.makeHttpRequest({
  url: url,
  method: "GET",
});

if (apiResponse.error) {
  throw Error("Weather API request failed: " + apiResponse.error.message);
}

/**
 * 2. PARAMETRIC LOGIC (The "Solar Justification")
 * We define a "Rainy Day" as any day where cloud cover or rain 
 * significantly drops solar efficiency.
 * * DEMO TRIGGERS:
 * - Zips starting with '9' (e.g., California) -> Simulating a rare "Storm Month" (22 Rainy Days)
 * - All other Zips -> Simulating "Sunny/Normal" (5 Rainy Days)
 */
let rainyDaysCount;

if (zipCode.startsWith('9')) {
    // This triggers the 'Weather Excuse' in your system logic
    rainyDaysCount = 22; 
    console.log(`Extreme weather detected for Zip ${zipCode}: ${rainyDaysCount} days.`);
} else {
    // This implies low revenue is likely due to hardware or host issues
    rainyDaysCount = 5;
    console.log(`Normal weather for Zip ${zipCode}: ${rainyDaysCount} days.`);
}

/**
 * 3. ENCODE & RETURN
 * Returns the uint256 to WeatherOracle.fulfillRequest()
 */
return Functions.encodeUint256(rainyDaysCount);