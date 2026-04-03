// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {SolarRevenueOracle} from "../../src/oracles/SolarRevenueOracle.sol";

contract SolarRevenueOracleTest is BaseTest {
    event GridRevenueSubmitted(uint256 indexed projectId, uint256 amount, uint256 timestamp);

    uint256 public projectId;

    function setUp() public override {
        super.setUp();
        projectId = _setupFullProject();
    }

    /*//////////////////////////////////////////////////////////////
                        BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that oracle can submit random revenue within acceptable range
    function test_SubmitGridRevenue_WithinRange() public {
        vm.prank(owner);
        oracle.submitGridRevenue(projectId);

        // Check that revenue was deposited to distributor
        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        
        // Should be within MIN_REVENUE and MAX_REVENUE
        assertGe(totalRevenue, oracle.MIN_REVENUE(), "Revenue below minimum");
        assertLe(totalRevenue, oracle.MAX_REVENUE(), "Revenue above maximum");
    }

    /// @notice Test that oracle can submit random revenue and verify it's within range
    function test_SubmitGridRevenue_ValidateRandomRevenue() public {
        vm.prank(owner);
        oracle.submitGridRevenue(projectId);

        // Verify revenue was submitted (implicit through the WithinRange test)
        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertGe(totalRevenue, oracle.MIN_REVENUE(), "Random revenue below minimum");
        assertLe(totalRevenue, oracle.MAX_REVENUE(), "Random revenue above maximum");
    }

    /// @notice Test that oracle can submit fixed revenue amounts
    function test_SubmitFixedRevenue() public {
        uint256 fixedAmount = 75 * 10 ** 6; // $75 USDC

        vm.prank(owner);
        oracle.submitFixedRevenue(projectId, fixedAmount);

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, fixedAmount, "Fixed revenue not deposited correctly");
    }

    /// @notice Test multiple revenue submissions accumulate
    function test_MultipleRevenueSubmissions() public {
        vm.startPrank(owner);
        
        oracle.submitFixedRevenue(projectId, 50 * 10 ** 6); // $50
        oracle.submitFixedRevenue(projectId, 75 * 10 ** 6); // $75
        oracle.submitFixedRevenue(projectId, 100 * 10 ** 6); // $100

        vm.stopPrank();

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, 225 * 10 ** 6, "Multiple submissions not accumulated");
    }

    /*//////////////////////////////////////////////////////////////
                        REVENUE GENERATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that pseudo-random generation produces different values
    function test_RandomRevenueVariation() public {
        uint256[] memory revenues = new uint256[](5);

        vm.prank(owner);
        for (uint256 i = 0; i < 5; i++) {
            oracle.submitGridRevenue(projectId);
            (revenues[i],,,,,, ) = distributor.projectRevenue(projectId);
            if (i > 0) {
                revenues[i] = revenues[i] - revenues[i-1]; // Get the individual amount
            }
        }

        // Check that not all revenues are the same (high probability)
        bool hasVariation = false;
        for (uint256 i = 1; i < 4; i++) {
            if (revenues[i] != revenues[i-1]) {
                hasVariation = true;
                break;
            }
        }
        assertTrue(hasVariation, "Revenue generation shows no variation");
    }

    /*//////////////////////////////////////////////////////////////
                        STATE AND IMMUTABLE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that oracle references correct USDC token
    function test_OracleUSDCReference() public {
        assertEq(address(oracle.usdc()), address(usdc), "Oracle USDC mismatch");
    }

    /// @notice Test that oracle references correct distributor
    function test_OracleDistributorReference() public {
        assertEq(address(oracle.distributor()), address(distributor), "Oracle distributor mismatch");
    }

    /// @notice Test that constants are correctly set
    function test_OracleConstants() public {
        assertEq(oracle.MIN_REVENUE(), 20 * 10 ** 6, "MIN_REVENUE incorrect");
        assertEq(oracle.MAX_REVENUE(), 150 * 10 ** 6, "MAX_REVENUE incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test submission at minimum revenue boundary
    function test_SubmitMinimumRevenue() public {
        uint256 minAmount = oracle.MIN_REVENUE();

        vm.prank(owner);
        oracle.submitFixedRevenue(projectId, minAmount);

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, minAmount, "Minimum revenue not deposited");
    }

    /// @notice Test submission at maximum revenue boundary
    function test_SubmitMaximumRevenue() public {
        uint256 maxAmount = oracle.MAX_REVENUE();

        vm.prank(owner);
        oracle.submitFixedRevenue(projectId, maxAmount);

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, maxAmount, "Maximum revenue not deposited");
    }

    /// @notice Test that oracle has sufficient USDC balance
    function test_OracleHasSufficientBalance() public {
        uint256 oracleBalance = usdc.balanceOf(address(oracle));
        assertGt(oracleBalance, 0, "Oracle has no USDC balance");
        assertGe(oracleBalance, oracle.MAX_REVENUE() * 10, "Oracle balance may be insufficient for testing");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that oracle revenue flows through distributor correctly
    function test_OracleRevenueFlowsToDistributor() public {
        (uint256 initialBalance,,,,,, ) = distributor.projectRevenue(projectId);

        vm.prank(owner);
        uint256 submissionAmount = 85 * 10 ** 6;
        oracle.submitFixedRevenue(projectId, submissionAmount);

        (uint256 finalBalance,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(finalBalance, initialBalance + submissionAmount, "Revenue not flowing correctly");
    }
}
