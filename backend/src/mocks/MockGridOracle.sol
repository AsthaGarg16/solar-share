// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";
import { IOracles } from "../interfaces/IOracles.sol";

contract MockGridOracle is IOracles {
    IERC20 public immutable usdc;
    IRevenueDistributor public immutable distributor;

    uint256 public constant MIN_REVENUE = 20 * 10 ** 6; 
    uint256 public constant MAX_REVENUE = 150 * 10 ** 6;

    mapping(uint256 => mapping(uint256 => uint256)) public monthlyProduction;

    event GridRevenueSubmitted(uint256 indexed projectId, uint256 amount, uint256 timestamp);

    constructor(address _usdc, address _distributor) {
        usdc = IERC20(_usdc);
        distributor = IRevenueDistributor(_distributor);
    }

    /*//////////////////////////////////////////////////////////////
                        REVENUE LOGIC
    //////////////////////////////////////////////////////////////*/

    function submitGridRevenue(uint256 projectId) external {
        _deposit(projectId, _generateRevenue());
    }

    function submitFixedRevenue(uint256 projectId, uint256 amount) external {
        _deposit(projectId, amount);
    }

    function _deposit(uint256 projectId, uint256 amount) internal {
        // Ensure the Mock has USDC to approve!
        usdc.approve(address(distributor), amount);
        distributor.depositGridRevenue(projectId, amount);
        emit GridRevenueSubmitted(projectId, amount, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        IOracles Implementation
    //////////////////////////////////////////////////////////////*/

    function setMockProduction(uint256 projectId, uint256 monthIndex, uint256 kwh) external {
        monthlyProduction[projectId][monthIndex] = kwh;
    }

    // Now returns the actual mapped value for testing "Low Production"
    function getProduction(uint256 projectId, uint256 month) external view override returns (uint256) {
        return monthlyProduction[projectId][month];
    }

    // Single declaration to avoid compiler errors
    function requestProduction(uint256, string calldata) external pure override returns (bytes32) { 
        return bytes32(0); 
    }

    function getRainyDays(uint256) external pure override returns (uint256) { return 0; }
    function requestWeatherCheck(uint256, string calldata) external pure override returns (bytes32) { return bytes32(0); }
    function triggerHardwareLock(uint256) external override {}
    function unlockHardware(uint256) external override {}

    function _generateRevenue() internal view returns (uint256) {
        uint256 range = MAX_REVENUE - MIN_REVENUE;
        uint256 pseudo = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        return MIN_REVENUE + (pseudo % range);
    }
}
