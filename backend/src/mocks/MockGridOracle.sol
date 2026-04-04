// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";

/// @notice Simulates grid revenue submissions ($20-$150/month)
contract MockGridOracle {
    IERC20 public immutable usdc;
    IRevenueDistributor public immutable distributor;

    uint256 public constant MIN_REVENUE = 20 * 10 ** 6; // $20 USDC
    uint256 public constant MAX_REVENUE = 150 * 10 ** 6; // $150 USDC

    event GridRevenueSubmitted(uint256 indexed projectId, uint256 amount, uint256 timestamp);

    constructor(address _usdc, address _distributor) {
        usdc = IERC20(_usdc);
        distributor = IRevenueDistributor(_distributor);
    }

    /// @notice Submit pseudo-random grid revenue for a project
    function submitGridRevenue(uint256 projectId) external {
        uint256 amount = _generateRevenue();
        usdc.approve(address(distributor), amount);
        distributor.depositGridRevenue(projectId, amount);
        emit GridRevenueSubmitted(projectId, amount, block.timestamp);
    }

    /// @notice Submit a specific amount of revenue (for testing)
    function submitFixedRevenue(uint256 projectId, uint256 amount) external {
        usdc.approve(address(distributor), amount);
        distributor.depositGridRevenue(projectId, amount);
        emit GridRevenueSubmitted(projectId, amount, block.timestamp);
    }

    function _generateRevenue() internal view returns (uint256) {
        uint256 range = MAX_REVENUE - MIN_REVENUE;
        uint256 pseudo = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        return MIN_REVENUE + (pseudo % range);
    }
}
