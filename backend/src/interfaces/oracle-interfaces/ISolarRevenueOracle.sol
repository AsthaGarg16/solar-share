// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISolarRevenueOracle {
    function submitGridRevenue(uint256 projectId) external;
    function submitFixedRevenue(uint256 projectId, uint256 amount) external;
}