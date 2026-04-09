// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// A host defaults on their loan. It physically shuts down the hardware. (The "Emergency Brake")
interface IIoTSolarOracle {
    function triggerHardwareLock(uint256 projectId) external returns (bytes32);
    
    function isKillswitchActive(uint256 projectId) external view returns (bool);
}