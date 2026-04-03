// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRevenueDistributor} from "../interfaces/IRevenueDistributor.sol";
import {ISolarRevenueOracle} from "../interfaces/oracle-interfaces/ISolarRevenueOracle.sol";

/**
 * @title SolarRevenueOracle
 * @notice Simulates grid revenue submissions ($20-$150 USDC per month)
 * @dev This contract bridges physical energy generation data to the blockchain.
 */
contract SolarRevenueOracle is ISolarRevenueOracle {
    IERC20 public immutable usdc;
    IRevenueDistributor public immutable distributor;

    // USDC uses 6 decimals: 20 * 10^6 = 20.000000 USDC
    uint256 public constant MIN_REVENUE = 20 * 10**6; 
    uint256 public constant MAX_REVENUE = 150 * 10**6; 

    event GridRevenueSubmitted(uint256 indexed projectId, uint256 amount, uint256 timestamp);

    constructor(address _usdc, address _distributor) {
        usdc = IERC20(_usdc);
        distributor = IRevenueDistributor(_distributor);
    }

    /**
     * @notice Submit pseudo-random grid revenue for a project.
     * @dev Simulates real-world variability in solar generation.
     * @param projectId The ID of the solar project receiving revenue.
     */
    function submitGridRevenue(uint256 projectId) external override {
        uint256 amount = _generateRevenue();
        
        // Approve the distributor to pull the USDC from this contract
        usdc.approve(address(distributor), amount);
        
        // Push the revenue into the Waterfall system
        distributor.depositGridRevenue(projectId, amount);
        
        emit GridRevenueSubmitted(projectId, amount, block.timestamp);
    }

    /**
     * @notice Submit a specific amount of revenue (primarily for testing/manual adjustments).
     * @param projectId The ID of the solar project.
     * @param amount The exact USDC amount (including 6 decimals).
     */
    function submitFixedRevenue(uint256 projectId, uint256 amount) external override {
        usdc.approve(address(distributor), amount);
        distributor.depositGridRevenue(projectId, amount);
        
        emit GridRevenueSubmitted(projectId, amount, block.timestamp);
    }

    /**
     * @dev Internal helper to generate a value between $20 and $150.
     * In production, this would be replaced by a Chainlink Function or signed API data.
     */
    function _generateRevenue() internal view returns (uint256) {
        uint256 range = MAX_REVENUE - MIN_REVENUE;
        // Using block properties for pseudo-randomness (safe for local simulation)
        uint256 pseudo = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        return MIN_REVENUE + (pseudo % range);
    }
}