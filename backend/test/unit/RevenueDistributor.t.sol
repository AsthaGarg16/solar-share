// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {RevenueDistributor} from "../../src/core/RevenueDistributor.sol";

contract RevenueDistributorTest is BaseTest {
  // Re-declare events for expectEmit
  event GridRevenueDeposited(uint256 indexed projectId, uint256 amount, uint256 timestamp);
  event HostPaymentDeposited(uint256 indexed projectId, uint256 amount, uint256 month);
  event WaterfallExecuted(
    uint256 indexed projectId,
    uint256 dividend,
    uint256 maintenance,
    uint256 insurance
  );
  event DividendsClaimed(uint256 indexed projectId, address indexed investor, uint256 amount);

  uint256 public projectId;
  uint256 constant GRID_REVENUE = 1000 * 10 ** 6; // $1,000 USDC

  function setUp() public override {
    super.setUp();
    projectId = _setupFullProject();

    // Setup permissions so the test contract/owner can act as the Oracle
    vm.startPrank(owner);
    distributor.setGridOracle(owner);
    distributor.setLoanManager(address(loanManager));
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                            DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

  function test_GridRevenueAutoWaterfalls() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);

    // This call triggers _executeWaterfallInternal automatically
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    // Access the 6-field struct:
    // 0: totalRevenue, 1: dividendPool, 2: maintenanceReserve, 3: insurancePool, 4: dividendPerShare, 5: currentMonth
    (uint256 totalRevenue, uint256 divPool, uint256 maint, uint256 ins, , ) = distributor
      .projectRevenue(projectId);

    assertEq(totalRevenue, 0, "Total revenue should be cleared by auto-waterfall");
    assertEq(divPool, (GRID_REVENUE * 93) / 100, "Dividend pool should be 93%");
    assertEq(maint, (GRID_REVENUE * 5) / 100, "Maintenance should be 5%");
    assertEq(ins, GRID_REVENUE - divPool - maint, "Insurance should be the remainder");
  }

  function test_HostPaymentIncrementsMonth() public {
    // LoanManager is the only one who can call this
    vm.startPrank(address(loanManager));
    usdc.mint(address(loanManager), MONTHLY_PAYMENT);
    usdc.approve(address(distributor), MONTHLY_PAYMENT);

    distributor.depositHostPayment(projectId, MONTHLY_PAYMENT);
    vm.stopPrank();

    (, , , , , uint256 month) = distributor.projectRevenue(projectId);
    assertEq(month, 1, "Month should increment on host payment");
  }

  function test_RevertWhen_UnauthorizedGridDeposit() public {
    vm.prank(investor1);
    vm.expectRevert(RevenueDistributor.OnlyGridOracle.selector);
    distributor.depositGridRevenue(projectId, 100);
  }

  /*//////////////////////////////////////////////////////////////
                           WATERFALL & MATH
    //////////////////////////////////////////////////////////////*/

  function test_DividendPerShareCalculation() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    uint256 expectedDividend = (GRID_REVENUE * 93) / 100;
    // Global shares from Base.t.sol is 1000
    uint256 expectedDPS = (expectedDividend * 1e18) / 1000;

    (, , , , uint256 dps, ) = distributor.projectRevenue(projectId);
    assertEq(dps, expectedDPS, "DPS math mismatch");
  }

  /*//////////////////////////////////////////////////////////////
                          CLAIMING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_InvestorsCanClaimProportionally() public {
    // Deposit $1000 -> $930 to dividends
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    // Investor1 has 500/1000 shares (50%)
    uint256 expectedClaim = ((GRID_REVENUE * 93) / 100) / 2; // $465

    uint256 balanceBefore = usdc.balanceOf(investor1);
    vm.prank(investor1);
    distributor.claimDividends(projectId);
    uint256 balanceAfter = usdc.balanceOf(investor1);

    assertEq(balanceAfter - balanceBefore, expectedClaim);
  }

  function test_RevertWhen_ClaimingTwice() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    vm.startPrank(investor1);
    distributor.claimDividends(projectId);

    vm.expectRevert(RevenueDistributor.NothingToClaim.selector);
    distributor.claimDividends(projectId);
    vm.stopPrank();
  }

  function test_GetClaimableDividendsView() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    uint256 claimable = distributor.getClaimableDividends(projectId, investor2);
    // Investor 2 has 300/1000 shares (30%)
    assertEq(claimable, (GRID_REVENUE * 93 * 30) / 100 / 100);
  }

  /*//////////////////////////////////////////////////////////////
                        MAINTENANCE & ADMIN
    //////////////////////////////////////////////////////////////*/

  function test_WithdrawMaintenanceAsAdmin() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);

    uint256 maintAmount = (GRID_REVENUE * 5) / 100; // $50

    uint256 balanceBefore = usdc.balanceOf(vendor);
    distributor.withdrawMaintenance(projectId, maintAmount, vendor);
    vm.stopPrank();

    assertEq(usdc.balanceOf(vendor) - balanceBefore, maintAmount);
  }

  function test_WithdrawInsuranceAsAdmin() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);

    (, , , uint256 insurance, , ) = distributor.projectRevenue(projectId);

    uint256 balanceBefore = usdc.balanceOf(owner);
    distributor.withdrawInsurance(projectId, insurance);
    vm.stopPrank();

    assertEq(usdc.balanceOf(owner) - balanceBefore, insurance);
  }

  function test_RevertWhen_NonMaintainerWithdraws() public {
    vm.startPrank(owner);
    usdc.mint(owner, GRID_REVENUE);
    usdc.approve(address(distributor), GRID_REVENUE);
    distributor.depositGridRevenue(projectId, GRID_REVENUE);
    vm.stopPrank();

    vm.prank(investor1);
    vm.expectRevert(); // AccessControl check
    distributor.withdrawMaintenance(projectId, 10, investor1);
  }
}
