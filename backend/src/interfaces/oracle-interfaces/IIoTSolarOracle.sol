// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IIoTSolarOracle {
    /// @notice Triggers the off-chain IoT killswitch via Chainlink Functions
    /// @param projectId The ID of the project in default
    /// @param hardwareApiId The serial number or API ID of the physical solar inverter
    /// @return requestId The unique ID of the Chainlink request
    function triggerKillswitch(uint256 projectId, string memory hardwareApiId) external returns (bytes32 requestId);

    /// @notice Checks if the killswitch has been successfully activated for a project
    function isKillswitchActive(uint256 projectId) external view returns (bool);
}