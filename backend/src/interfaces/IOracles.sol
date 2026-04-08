// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracles {
    // --- Weather Oracle Functions ---
    /// @notice Returns the number of rainy days recorded for a project
    function getRainyDays(uint256 projectId) external view returns (uint256);

    /// @notice Triggers a new weather data fetch
    function requestWeatherCheck(uint256 projectId, string calldata zipCode) external returns (bytes32);

    // --- Grid Oracle Functions ---
    /// @notice Returns the actual kWh produced by the solar panels
    function getProduction(uint256 projectId, uint256 monthIndex) external view returns (uint256);

    /// @notice Triggers a new production data fetch from the smart meter
    function requestProduction(uint256 projectId, string calldata meterId) external returns (bytes32);

    // --- IoT Oracle Functions ---
    /// @notice Signals the physical hardware to lock/unlock
    function triggerHardwareLock(uint256 projectId) external;
    
    function unlockHardware(uint256 projectId) external;
}