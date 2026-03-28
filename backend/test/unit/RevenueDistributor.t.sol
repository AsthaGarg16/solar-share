// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {RevenueDistributor} from "../../src/core/RevenueDistributor.sol";

contract RevenueDistributorTest is BaseTest {
    // Re-declare events for expectEmit
    event GridRevenueDeposited(uint256 indexed projectId, uint256 amount, uint256 timestamp);
    event HostPaymentDeposited(uint256 indexed projectId, uint256 amount, uint256 month);
    event WaterfallExecuted(uint256 indexed projectId, uint256 totalRevenue, uint256 dividendAmount, uint256 maintenanceAmount, uint256 insuranceAmount);
    event DividendsClaimed(uint256 indexed projectId, address indexed investor, uint256 amount);

    uint256 public projectId;

    uint256 constant GRID_REVENUE = 80 * 10 ** 6; // $80

    function setUp() public override {
        super.setUp();
        projectId = _setupFullProject();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GridRevenueDeposited() public {
        vm.startPrank(owner);
        usdc.mint(owner, GRID_REVENUE);
        usdc.approve(address(distributor), GRID_REVENUE);
        distributor.depositGridRevenue(projectId, GRID_REVENUE);
        vm.stopPrank();

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, GRID_REVENUE);
    }

    function test_GridRevenueAddsToTotalRevenue() public {
        uint256 amount1 = 50 * 10 ** 6;
        uint256 amount2 = 30 * 10 ** 6;

        vm.startPrank(owner);
        usdc.mint(owner, amount1 + amount2);
        usdc.approve(address(distributor), amount1 + amount2);
        distributor.depositGridRevenue(projectId, amount1);
        distributor.depositGridRevenue(projectId, amount2);
        vm.stopPrank();

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, amount1 + amount2);
    }

    function test_GridRevenueEmitsEvent() public {
        vm.startPrank(owner);
        usdc.mint(owner, GRID_REVENUE);
        usdc.approve(address(distributor), GRID_REVENUE);
        vm.expectEmit(true, false, false, true);
        emit GridRevenueDeposited(projectId, GRID_REVENUE, block.timestamp);
        distributor.depositGridRevenue(projectId, GRID_REVENUE);
        vm.stopPrank();
    }

    function test_HostPaymentDepositedViaLoanManager() public {
        // The loan manager deposits host payment after host pays
        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();

        // totalRevenue should be MONTHLY_PAYMENT
        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, MONTHLY_PAYMENT);
    }

    function test_RevertWhen_DirectHostPaymentNotFromLoanManager() public {
        vm.startPrank(host);
        usdc.approve(address(distributor), MONTHLY_PAYMENT);
        vm.expectRevert(RevenueDistributor.OnlyLoanManager.selector);
        distributor.depositHostPayment(projectId, MONTHLY_PAYMENT);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           WATERFALL TESTS
    //////////////////////////////////////////////////////////////*/

    function _depositRevenue(uint256 amount) internal {
        vm.startPrank(owner);
        usdc.mint(owner, amount);
        usdc.approve(address(distributor), amount);
        distributor.depositGridRevenue(projectId, amount);
        vm.stopPrank();
    }

    function _depositHostPayment() internal {
        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();
    }

    function test_ExecuteWaterfallSplits93_5_2() public {
        uint256 total = 280 * 10 ** 6; // $280
        _depositRevenue(total);

        distributor.executeWaterfall(projectId);

        (
            uint256 totalRevenue,
            uint256 dividendPool,
            uint256 maintenanceReserve,
            uint256 insurancePool,
            ,
            ,
        ) = distributor.projectRevenue(projectId);

        assertEq(totalRevenue, 0); // Reset to 0
        assertEq(dividendPool, (total * 93) / 100); // 93%
        assertEq(maintenanceReserve, (total * 5) / 100); // 5%
        // Insurance gets the remainder to avoid dust
        assertEq(insurancePool, total - (total * 93 / 100) - (total * 5 / 100)); // ~2%
    }

    function test_DividendPoolReceivesExactly93Percent() public {
        uint256 total = 1000 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        (, uint256 dividendPool,,,,,) = distributor.projectRevenue(projectId);
        assertEq(dividendPool, 930 * 10 ** 6);
    }

    function test_MaintenanceReserveReceivesExactly5Percent() public {
        uint256 total = 1000 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        (,, uint256 maintenanceReserve,,,,) = distributor.projectRevenue(projectId);
        assertEq(maintenanceReserve, 50 * 10 ** 6);
    }

    function test_TotalRevenueResetToZeroAfterWaterfall() public {
        _depositRevenue(100 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        (uint256 totalRevenue,,,,,, ) = distributor.projectRevenue(projectId);
        assertEq(totalRevenue, 0);
    }

    function test_DividendPerShareUpdatedCorrectly() public {
        uint256 total = 280 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        uint256 dividendAmount = (total * 93) / 100;
        uint256 expectedDPS = (dividendAmount * 1e18) / TOTAL_SHARES;

        (,,,, uint256 dividendPerShare,,) = distributor.projectRevenue(projectId);
        assertEq(dividendPerShare, expectedDPS);
    }

    function test_WaterfallEmitsEvent() public {
        uint256 total = 280 * 10 ** 6;
        _depositRevenue(total);

        vm.expectEmit(true, false, false, false);
        emit WaterfallExecuted(projectId, total, 0, 0, 0);
        distributor.executeWaterfall(projectId);
    }

    function test_MultipleWaterfallsAccumulate() public {
        uint256 total = 280 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        uint256 dividendAmount = (total * 93) / 100;
        uint256 expectedDPS = ((dividendAmount * 1e18) / TOTAL_SHARES) * 2;

        (,,,, uint256 dividendPerShare,,) = distributor.projectRevenue(projectId);
        assertEq(dividendPerShare, expectedDPS);
    }

    function test_ZeroRevenueWaterfallNoChange() public {
        (,,,, uint256 dpsBefore,,) = distributor.projectRevenue(projectId);
        distributor.executeWaterfall(projectId);
        (,,,, uint256 dpsAfter,,) = distributor.projectRevenue(projectId);
        assertEq(dpsBefore, dpsAfter);
    }

    /*//////////////////////////////////////////////////////////////
                         DIVIDEND CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InvestorCanClaimDividends() public {
        _depositHostPayment();
        _depositRevenue(GRID_REVENUE);
        distributor.executeWaterfall(projectId);

        uint256 claimable = distributor.getClaimableDividends(projectId, investor1);
        assertGt(claimable, 0);

        uint256 balanceBefore = usdc.balanceOf(investor1);
        vm.prank(investor1);
        distributor.claimDividends(projectId);
        assertEq(usdc.balanceOf(investor1) - balanceBefore, claimable);
    }

    function test_ClaimAmountMatchesSharePercentage() public {
        uint256 total = 1000 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        uint256 dividendPool = (total * 93) / 100; // $930

        // investor1 has 50% of shares
        uint256 claimable1 = distributor.getClaimableDividends(projectId, investor1);
        assertEq(claimable1, dividendPool / 2);

        // investor2 has 30% of shares
        uint256 claimable2 = distributor.getClaimableDividends(projectId, investor2);
        assertEq(claimable2, (dividendPool * 30) / 100);

        // investor3 has 20% of shares
        uint256 claimable3 = distributor.getClaimableDividends(projectId, investor3);
        assertEq(claimable3, (dividendPool * 20) / 100);
    }

    function test_CannotClaimMoreThanOwed() public {
        _depositRevenue(100 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        vm.prank(investor1);
        distributor.claimDividends(projectId);

        // Try to claim again - should revert
        vm.prank(investor1);
        vm.expectRevert(RevenueDistributor.NothingToClaim.selector);
        distributor.claimDividends(projectId);
    }

    function test_CannotClaimTwiceWithoutNewRevenue() public {
        _depositRevenue(100 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        vm.prank(investor1);
        distributor.claimDividends(projectId);

        vm.prank(investor1);
        vm.expectRevert(RevenueDistributor.NothingToClaim.selector);
        distributor.claimDividends(projectId);
    }

    function test_ClaimedDividendsUpdatedAfterClaim() public {
        _depositRevenue(100 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        vm.prank(investor1);
        distributor.claimDividends(projectId);

        (,,,, uint256 dps,,) = distributor.projectRevenue(projectId);
        uint256 shares = solarProject.getInvestorShares(projectId, investor1);
        uint256 expectedClaimed = (shares * dps) / 1e18;
        assertEq(distributor.claimedDividends(projectId, investor1), expectedClaimed);
    }

    function test_ClaimDividendsEmitsEvent() public {
        _depositRevenue(100 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        vm.prank(investor1);
        vm.expectEmit(true, true, false, false);
        emit DividendsClaimed(projectId, investor1, 0);
        distributor.claimDividends(projectId);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-PERIOD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DividendsAccumulateOverMultipleMonths() public {
        uint256 totalExpected;
        for (uint256 i = 0; i < 3; i++) {
            uint256 revenue = 100 * 10 ** 6;
            _depositRevenue(revenue);
            distributor.executeWaterfall(projectId);
            totalExpected += (revenue * 93 / 100 * 50) / 100; // 50% for investor1
            vm.warp(block.timestamp + 30 days);
        }

        uint256 claimable = distributor.getClaimableDividends(projectId, investor1);
        assertEq(claimable, totalExpected);
    }

    function test_InvestorCanClaimAllAccumulatedAtOnce() public {
        for (uint256 i = 0; i < 5; i++) {
            _depositRevenue(100 * 10 ** 6);
            distributor.executeWaterfall(projectId);
            vm.warp(block.timestamp + 30 days);
        }

        uint256 claimable = distributor.getClaimableDividends(projectId, investor1);
        uint256 balanceBefore = usdc.balanceOf(investor1);

        vm.prank(investor1);
        distributor.claimDividends(projectId);

        assertEq(usdc.balanceOf(investor1) - balanceBefore, claimable);
    }

    function test_MultipleInvestorsClaimProportionally() public {
        uint256 total = 1000 * 10 ** 6;
        _depositRevenue(total);
        distributor.executeWaterfall(projectId);

        uint256 dividendPool = (total * 93) / 100;

        vm.prank(investor1);
        uint256 claimed1 = distributor.claimDividends(projectId);

        vm.prank(investor2);
        uint256 claimed2 = distributor.claimDividends(projectId);

        vm.prank(investor3);
        uint256 claimed3 = distributor.claimDividends(projectId);

        // investor1: 50%, investor2: 30%, investor3: 20%
        assertEq(claimed1, dividendPool / 2);
        assertEq(claimed2, (dividendPool * 30) / 100);
        assertEq(claimed3, (dividendPool * 20) / 100);
    }

    /*//////////////////////////////////////////////////////////////
                           GOVERNANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanWithdrawMaintenance() public {
        _depositRevenue(1000 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        uint256 balanceBefore = usdc.balanceOf(owner);
        vm.prank(owner);
        distributor.withdrawMaintenance(projectId, 50 * 10 ** 6, owner); // 5% of $1000
        assertEq(usdc.balanceOf(owner) - balanceBefore, 50 * 10 ** 6);
    }

    function test_OwnerCanWithdrawInsurance() public {
        _depositRevenue(1000 * 10 ** 6);
        distributor.executeWaterfall(projectId);

        vm.prank(owner);
        (,,, uint256 insurancePool,,,) = distributor.projectRevenue(projectId);

        uint256 balanceBefore = usdc.balanceOf(owner);
        vm.prank(owner);
        distributor.withdrawInsurance(projectId, insurancePool);
        assertEq(usdc.balanceOf(owner) - balanceBefore, insurancePool);
    }

    function test_RevertWhen_InsufficientMaintenance() public {
        vm.prank(owner);
        vm.expectRevert(RevenueDistributor.InsufficientMaintenance.selector);
        distributor.withdrawMaintenance(projectId, 1, owner);
    }
}
