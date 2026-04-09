// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWeatherOracle {
    function requestWeatherCheck(uint256 projectId, string calldata zipCode) external returns (bytes32);
    
    function getRainyDays(uint256 projectId) external view returns (uint256);
}