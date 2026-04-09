// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IIoTSolarOracle } from "../interfaces/IIoTSolarOracle.sol";

/// @title Mock IoT Solar Oracle
/// @notice Simulates an instant response from the hardware for local testing
contract MockIoTSolarOracle is IIoTSolarOracle {
    mapping(uint256 => bool) public killswitchStatus;
    uint256 private nextRequestId = 1;

    // RENAME THIS: from triggerKillswitch to triggerHardwareLock
    function triggerHardwareLock(uint256 projectId) external returns (bytes32) {
        // In the mock, we simulate an instant successful response from the hardware
        killswitchStatus[projectId] = true;
        
        bytes32 reqId = bytes32(nextRequestId);
        nextRequestId++;
        
        return reqId;
    }

    function isKillswitchActive(uint256 projectId) external view returns (bool) {
        return killswitchStatus[projectId];
    }
}