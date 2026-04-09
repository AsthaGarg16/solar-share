// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {LoanManager} from "../../src/core/LoanManager.sol";
import {SolarProject} from "../../src/core/SolarProject.sol";
import {ISolarProject} from "../../src/interfaces/ISolarProject.sol";

contract LoanManagerTest is BaseTest {
  // Re-declare events for expectEmit
  event LoanInitialized(uint256 indexed projectId, uint256 monthlyPayment, uint256 termMonths);
  event PaymentReceived(
    uint256 indexed projectId,
    uint256 month,
    uint256 amount,
    uint256 timestamp
  );
  event DefaultDeclared(uint256 indexed projectId, uint256 missedMonth, address host);
  event LoanCompleted(uint256 indexed projectId, uint256 totalPaid);

  uint256 public projectId;

  function setUp() public override {
    super.setUp();
    projectId = _fundProjectFully();
    vm.prank(host);
    reputation.mintSbt(host);
  }

  /*//////////////////////////////////////////////////////////////
                         INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_InitializeLoan() public {
    // Loan is initialized via withdrawFunds
    _initializeLoan(projectId);

    (
      uint256 pid,
      uint256 monthlyPayment,
      uint256 termMonths,
      uint256 currentMonth,
      ,
      uint256 nextPaymentDue,
      uint256 totalPaid,
      uint256 totalOwed,
      bool isDefaulted,
      bool isCompleted,
      bool initialized
    ) = loanManager.projectLoans(projectId);

    assertEq(pid, projectId);
    assertEq(monthlyPayment, MONTHLY_PAYMENT);
    assertEq(termMonths, TERM_MONTHS);
    assertEq(currentMonth, 0);
    assertEq(totalPaid, 0);
    assertEq(totalOwed, MONTHLY_PAYMENT * TERM_MONTHS);
    assertFalse(isDefaulted);
    assertFalse(isCompleted);
    assertTrue(initialized);
    assertGt(nextPaymentDue, block.timestamp);
  }

  function test_RevertWhen_InitializeLoanTwice() public {
    // First withdrawFunds initializes the loan; second call hits LoanAlreadyInitialized in LoanManager
    vm.prank(host);
    solarProject.withdrawFunds(projectId);

    vm.prank(host);
    vm.expectRevert(LoanManager.LoanAlreadyInitialized.selector);
    solarProject.withdrawFunds(projectId);
  }

  function test_RevertWhen_InitializeUnfundedProject() public {
    uint256 newProjectId = _createProject();
    vm.prank(host);
    vm.expectRevert(SolarProject.ProjectNotFullyFunded.selector);
    solarProject.withdrawFunds(newProjectId);
  }

  function test_TotalOwedCalculatedCorrectly() public {
    vm.prank(host);
    solarProject.withdrawFunds(projectId);

    (, , , , , , , uint256 totalOwed, , , ) = loanManager.projectLoans(projectId);
    assertEq(totalOwed, MONTHLY_PAYMENT * TERM_MONTHS);
  }

  function test_NextPaymentDueSetCorrectly() public {
    vm.prank(host);
    solarProject.withdrawFunds(projectId);

    (, , , , , uint256 nextPaymentDue, , , , , ) = loanManager.projectLoans(projectId);
    assertEq(nextPaymentDue, block.timestamp + 30 days);
  }

  function test_InitializeLoan_EmitsLoanInitialized() public {
    vm.prank(host);
    vm.expectEmit(true, false, false, true);
    emit LoanInitialized(projectId, MONTHLY_PAYMENT, TERM_MONTHS);
    solarProject.withdrawFunds(projectId);
  }

  function test_RevertWhen_WithdrawFundsOnlyByHost() public {
    vm.prank(investor1);
    vm.expectRevert(SolarProject.OnlyHostOrLoanManager.selector);
    solarProject.withdrawFunds(projectId);
  }

  /*//////////////////////////////////////////////////////////////
                            PAYMENT TESTS
    //////////////////////////////////////////////////////////////*/

  function test_HostCanMakePayment() public {
    _initializeLoan(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    (, , , uint256 currentMonth, , , uint256 totalPaid, , , , ) = loanManager.projectLoans(
      projectId
    );
    assertEq(currentMonth, 1);
    assertEq(totalPaid, MONTHLY_PAYMENT);
  }

  function test_PaymentTransfersUSDC() public {
    _initializeLoan(projectId);
    uint256 balanceBefore = usdc.balanceOf(host);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    assertEq(usdc.balanceOf(host), balanceBefore - MONTHLY_PAYMENT);
  }

  function test_CurrentMonthIncrementsAfterPayment() public {
    _initializeLoan(projectId);
    assertEq(loanManager.getCurrentMonth(projectId), 0);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    assertEq(loanManager.getCurrentMonth(projectId), 1);
  }

  function test_NextPaymentDueUpdatedAfterPayment() public {
    _initializeLoan(projectId);

    (, , , , , uint256 initialNextDue, , , , , ) = loanManager.projectLoans(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    (, , , , , uint256 nextPaymentDue, , , , , ) = loanManager.projectLoans(projectId);
    assertEq(nextPaymentDue, initialNextDue + 30 days);
  }

  function test_TotalPaidUpdatesAfterPayment() public {
    _initializeLoan(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT * 2);
    loanManager.payMonthlyInstallment(projectId);
    vm.warp(block.timestamp + 30 days);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    (, , , , , , uint256 totalPaid, , , , ) = loanManager.projectLoans(projectId);
    assertEq(totalPaid, MONTHLY_PAYMENT * 2);
  }

  function test_RevertWhen_PayIfDefaulted() public {
    _initializeLoan(projectId);

    // Warp past deadline and declare default
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert(LoanManager.InDefault.selector);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  function test_PaymentEmitsPaymentReceived() public {
    _initializeLoan(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectEmit(true, false, false, true);
    emit PaymentReceived(projectId, 1, MONTHLY_PAYMENT, block.timestamp);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  function test_RevertWhen_NonHostPays() public {
    _initializeLoan(projectId);

    vm.startPrank(investor1);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert(LoanManager.NotProjectHost.selector);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                       DEFAULT DETECTION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_CheckDefaultStatusFalseWhenCurrent() public {
    _initializeLoan(projectId);
    assertFalse(loanManager.checkDefaultStatus(projectId));
  }

  function test_CheckDefaultStatusTrueAfterDeadline() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    assertTrue(loanManager.checkDefaultStatus(projectId));
  }

  function test_CheckDefaultStatusTrueIfDefaultedFlagSet() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);
    assertTrue(loanManager.checkDefaultStatus(projectId));
  }

  function test_CheckDefaultStatusFalseAfterPayment() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 25 days); // Still within grace period

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    assertFalse(loanManager.checkDefaultStatus(projectId));
  }

  /*//////////////////////////////////////////////////////////////
                       DEFAULT DECLARATION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_CanDeclareDefaultAfterDeadline() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);

    (, , , , , , , , bool isDefaulted, , ) = loanManager.projectLoans(projectId);
    assertTrue(isDefaulted);
  }

  function test_RevertWhen_DeclareDefaultBeforeDeadline() public {
    _initializeLoan(projectId);
    vm.expectRevert(LoanManager.NotInDefault.selector);
    loanManager.declareDefault(projectId);
  }

  function test_DefaultSetsIsDefaultedFlag() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);

    (, , , , , , , , bool isDefaulted, , ) = loanManager.projectLoans(projectId);
    assertTrue(isDefaulted);
  }

  function test_DefaultCallsHostReputationSlash() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);

    // Host reputation before
    uint256 scoreBefore = reputation.getScore(host);

    loanManager.declareDefault(projectId);

    uint256 scoreAfter = reputation.getScore(host);
    assertEq(scoreAfter, scoreBefore - 200);
  }

  function test_DefaultChangesProjectStatusToDefaulted() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Defaulted));
  }

  function test_DefaultEmitsDefaultDeclared() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);

    vm.expectEmit(true, false, false, false);
    emit DefaultDeclared(projectId, 1, host);
    loanManager.declareDefault(projectId);
  }

  function test_RevertWhen_DeclareDefaultTwice() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);
    loanManager.declareDefault(projectId);

    vm.expectRevert(LoanManager.AlreadyDefaulted.selector);
    loanManager.declareDefault(projectId);
  }

  /*//////////////////////////////////////////////////////////////
                          EQUITY SPLIT TESTS
    //////////////////////////////////////////////////////////////*/

  function test_EquitySplitAtMonth0() public {
    _initializeLoan(projectId);
    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPercent, 0);
    assertEq(investorPercent, 100);
  }

  function test_EquitySplitAtMonth1() public {
    _initializeLoan(projectId);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    // 1 * 100 / 120 = 0 (integer division)
    assertEq(hostPercent, 0);
    assertEq(investorPercent, 100);
  }

  function test_EquitySplitAtMonth12() public {
    _initializeLoan(projectId);

    // Make 12 payments
    for (uint256 i = 0; i < 12; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPercent, 10); // 12 * 100 / 120 = 10
    assertEq(investorPercent, 90);
  }

  function test_EquitySplitAtMonth60() public {
    _initializeLoan(projectId);

    // Make 60 payments
    for (uint256 i = 0; i < 60; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPercent, 50); // 60 * 100 / 120 = 50
    assertEq(investorPercent, 50);
  }

  function test_EquitySplitSumsTo100() public {
    _initializeLoan(projectId);

    for (uint256 i = 0; i < 30; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPercent + investorPercent, 100);
  }

  /*//////////////////////////////////////////////////////////////
                           COMPLETION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_LoanMarkedCompleteAfterFinalPayment() public {
    _initializeLoan(projectId);

    // Make all 120 payments
    for (uint256 i = 0; i < TERM_MONTHS; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    (, , , , , , , , , bool isCompleted, ) = loanManager.projectLoans(projectId);
    assertTrue(isCompleted);
  }

  function test_LoanCompleted_EmitsEvent() public {
    _initializeLoan(projectId);

    for (uint256 i = 0; i < TERM_MONTHS - 1; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    // Final payment
    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectEmit(true, false, false, false);
    emit LoanCompleted(projectId, MONTHLY_PAYMENT * TERM_MONTHS);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  function test_RevertWhen_PayAfterLoanCompleted() public {
    _initializeLoan(projectId);

    for (uint256 i = 0; i < TERM_MONTHS; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert(LoanManager.LoanAlreadyCompleted.selector);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  function test_CheckDefaultStatusFalseAfterCompletion() public {
    _initializeLoan(projectId);

    for (uint256 i = 0; i < TERM_MONTHS; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    // After completion, even past deadline, not in default
    vm.warp(block.timestamp + 60 days);
    assertFalse(loanManager.checkDefaultStatus(projectId));
  }

  // LoanNotInitialized branch in payMonthlyInstallment
  function test_RevertWhen_PayOnUninitializedLoan() public {
    // projectId is funded but withdrawFunds was never called → loan not initialized
    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert(LoanManager.LoanNotInitialized.selector);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }

  // InvalidMonthlyPayment branch in initializeLoan
  function test_RevertWhen_InitializeWithZeroMonthlyPayment() public {
    // monthlyPayment == 0 check fires before the project-status check
    vm.expectRevert(LoanManager.InvalidMonthlyPayment.selector);
    loanManager.initializeLoan(projectId, 0, TERM_MONTHS);
  }

  // LoanAlreadyCompleted branch in declareDefault
  function test_RevertWhen_DeclareDefaultOnCompletedLoan() public {
    _initializeLoan(projectId);

    for (uint256 i = 0; i < TERM_MONTHS; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    // Past the deadline but loan is completed — should revert with LoanAlreadyCompleted
    vm.warp(block.timestamp + 31 days);
    vm.expectRevert(LoanManager.LoanAlreadyCompleted.selector);
    loanManager.declareDefault(projectId);
  }

  // rainyDays > RAINY_DAY_THRESHOLD branch in declareDefault (DefaultExcused path)
  function test_DefaultExcusedByWeather() public {
    _initializeLoan(projectId);
    vm.warp(block.timestamp + 31 days);

    // Set rainy days above the 15-day threshold
    weatherOracle.setRainyDays(projectId, 20);
    loanManager.declareDefault(projectId);

    // Loan should NOT be defaulted — it was excused
    (, , , , , , , , bool isDefaulted, , ) = loanManager.projectLoans(projectId);
    assertFalse(isDefaulted);
  }

  // DefaultExcused extends the payment deadline
  function test_DefaultExcused_ExtendsNextPaymentDue() public {
    _initializeLoan(projectId);
    (, , , , , uint256 originalDue, , , , , ) = loanManager.projectLoans(projectId);

    vm.warp(block.timestamp + 31 days);
    weatherOracle.setRainyDays(projectId, 20);
    loanManager.declareDefault(projectId);

    (, , , , , uint256 newDue, , , , , ) = loanManager.projectLoans(projectId);
    assertGt(newDue, originalDue);
  }

  // !loan.initialized branch in checkDefaultStatus (returns false for uninitialized)
  function test_CheckDefaultStatus_ReturnsFalseWhenNotInitialized() public {
    // Warp past deadline — loan not initialized so should still return false
    vm.warp(block.timestamp + 31 days);
    assertFalse(loanManager.checkDefaultStatus(projectId));
  }

  // !loan.initialized branch in calculateEquitySplit (returns 0, 100)
  function test_CalculateEquitySplit_UninitializedLoanReturnsDefault() public {
    // projectId loan is not initialized (no withdrawFunds called in this test)
    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPercent, 0);
    assertEq(investorPercent, 100);
  }

  // address(revenueDistributor) == address(0) branch in payMonthlyInstallment
  function test_RevertWhen_RevenueDistributorNotSet() public {
    _initializeLoan(projectId);

    // Clear the distributor address (owner is allowed by setRevenueDistributor)
    vm.prank(owner);
    loanManager.setRevenueDistributor(address(0));

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert(LoanManager.RevenueDistributorNotSet.selector);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();
  }
}
