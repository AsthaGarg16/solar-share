export const WeatherOracleABI = [
  {
    type: "function",
    name: "getRainyDays",
    inputs: [{ name: "projectId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "mockSetRainyDays",
    inputs: [
      { name: "projectId", type: "uint256" },
      { name: "rainyDays", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;

