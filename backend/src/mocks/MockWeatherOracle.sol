// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockWeatherOracle {
    mapping(uint256 => uint256) public projectRainyDays;

    /// @notice Allows tests to manually set rainy days for a project
    function setRainyDays(uint256 projectId, uint256 daysCount) external {
        projectRainyDays[projectId] = daysCount;
    }
    
    // Simulate the Chainlink request
    function requestWeatherCheck(uint256 projectId, string memory zipCode) external returns (bytes32) {
        // Logic: if zip starts with '9', set 22 days, else 5
        bytes memory zipBytes = bytes(zipCode);
        if (zipBytes.length > 0 && zipBytes[0] == '9') {
            projectRainyDays[projectId] = 22;
        } else {
            projectRainyDays[projectId] = 5;
        }
        return keccak256(abi.encodePacked(projectId, block.timestamp));
    }

    function getRainyDays(uint256 projectId) external view returns (uint256) {
        return projectRainyDays[projectId];
    }
}