// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {ISolarProject} from "../../src/interfaces/ISolarProject.sol";
import {SolarProject} from "../../src/core/SolarProject.sol";

contract SolarProjectTest is BaseTest {
  // Re-declare events for expectEmit
  event ProjectCreated(
    uint256 indexed projectId,
    address indexed host,
    uint256 targetAmount,
    uint256 termMonths
  );
  event ProjectFunded(
    uint256 indexed projectId,
    address indexed investor,
    uint256 numShares,
    uint256 amount
  );
  event SharesMinted(uint256 indexed projectId, address indexed investor, uint256 numShares);
  event BuyoutTriggered(
    uint256 indexed projectId,
    uint256 offerAmount,
    uint256 hostShare,
    uint256 investorShare
  );
  event FundsWithdrawn(uint256 indexed projectId, address indexed host, uint256 amount);
  event ProjectStatusChanged(uint256 indexed projectId, ISolarProject.ProjectStatus newStatus);

  uint256 public projectId;

  /*//////////////////////////////////////////////////////////////
                           INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_InitializeProject() public {
    vm.prank(host);
    projectId = solarProject.initializeProject(
      "Test Project",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(project.host, host);
    assertEq(project.name, "Test Project");
    assertEq(project.targetAmount, TARGET_AMOUNT);
    assertEq(project.termMonths, TERM_MONTHS);
    assertEq(project.totalShares, TOTAL_SHARES);
    assertEq(project.amountRaised, 0);
    assertEq(project.sharesSold, 0);
  }

  function test_ProjectIdIncrements() public {
    vm.startPrank(host);
    uint256 id1 = solarProject.initializeProject(
      "Project 1",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );
    uint256 id2 = solarProject.initializeProject(
      "Project 2",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );
    vm.stopPrank();
    assertEq(id1, 1);
    assertEq(id2, 2);
  }

  function test_InitialStatusIsFunding() public {
    projectId = _createProject();
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Funding));
  }

  function test_PricePerShareCalculatedCorrectly() public {
    projectId = _createProject();
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    // $20,000 / 1000 shares = $20 per share
    assertEq(project.pricePerShare, 20 * 10 ** 6);
  }

  function test_InitializeProject_EmitsProjectCreated() public {
    vm.prank(host);
    vm.expectEmit(true, true, false, true);
    emit ProjectCreated(1, host, TARGET_AMOUNT, TERM_MONTHS);
    solarProject.initializeProject("Solar Project Alpha", TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
  }

  function test_RevertWhen_InitializeWithZeroTargetAmount() public {
    vm.prank(host);
    vm.expectRevert(SolarProject.InvalidTargetAmount.selector);
    solarProject.initializeProject("Test", 0, TERM_MONTHS, TOTAL_SHARES);
  }

  function test_RevertWhen_InitializeWithZeroTermMonths() public {
    vm.prank(host);
    vm.expectRevert(SolarProject.InvalidTermMonths.selector);
    solarProject.initializeProject("Solar Project Alpha", TARGET_AMOUNT, 0, TOTAL_SHARES);
  }

  function test_RevertWhen_InitializeWithZeroTotalShares() public {
    vm.prank(host);
    vm.expectRevert(SolarProject.InvalidTotalShares.selector);
    solarProject.initializeProject("Test", TARGET_AMOUNT, TERM_MONTHS, 0);
  }

  /*//////////////////////////////////////////////////////////////
                              FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_SingleInvestorCanFund() public {
    projectId = _createProject();
    uint256 numShares = 100;
    uint256 amount = numShares * 20 * 10 ** 6; // $20 per share

    vm.startPrank(investor1);
    usdc.approve(address(solarProject), amount);
    solarProject.fundProject(projectId, numShares);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(project.sharesSold, numShares);
    assertEq(project.amountRaised, amount);
  }

  function test_MultipleInvestorsCanFund() public {
    projectId = _createProject();

    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();

    vm.startPrank(investor2);
    usdc.approve(address(solarProject), 6_000 * 10 ** 6);
    solarProject.fundProject(projectId, 300);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(project.sharesSold, 800);
    assertEq(project.amountRaised, 16_000 * 10 ** 6);
  }

  function test_SharesMintedCorrectly() public {
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();

    assertEq(solarProject.getInvestorShares(projectId, investor1), 500);
  }

  function test_USDCTransferredFromInvestor() public {
    projectId = _createProject();
    uint256 balanceBefore = usdc.balanceOf(investor1);

    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();

    assertEq(usdc.balanceOf(investor1), balanceBefore - 10_000 * 10 ** 6);
  }

  function test_AmountRaisedUpdatesCorrectly() public {
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 4_000 * 10 ** 6);
    solarProject.fundProject(projectId, 200);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(project.amountRaised, 4_000 * 10 ** 6);
  }

  function test_SharesSoldUpdatesCorrectly() public {
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 4_000 * 10 ** 6);
    solarProject.fundProject(projectId, 200);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(project.sharesSold, 200);
  }

  function test_RevertWhen_FundMoreThanTotalShares() public {
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 25_000 * 10 ** 6);
    vm.expectRevert(SolarProject.ExceedsAvailableShares.selector);
    solarProject.fundProject(projectId, 1001); // Only 1000 available
    vm.stopPrank();
  }

  function test_StatusChangesToActiveWhenFullyFunded() public {
    projectId = _fundProjectFully();
    // Status becomes Active only after withdrawFunds (which triggers loan initialization)
    vm.prank(host);
    reputation.mintSbt(host);
    _initializeLoan(projectId);
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Active));
  }

  function test_IsFundedSetToTrueWhenComplete() public {
    projectId = _fundProjectFully();
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertTrue(project.isFunded);
  }

  function test_RevertWhen_FundAfterProjectFullyFunded() public {
    projectId = _fundProjectFully();
    // All shares sold — trying to buy one more reverts with ExceedsAvailableShares
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 20 * 10 ** 6);
    vm.expectRevert(SolarProject.ExceedsAvailableShares.selector);
    solarProject.fundProject(projectId, 1);
    vm.stopPrank();
  }

  function test_RevertWhen_FundWithZeroShares() public {
    projectId = _createProject();
    vm.prank(investor1);
    vm.expectRevert(SolarProject.ZeroShares.selector);
    solarProject.fundProject(projectId, 0);
  }

  function test_FundProject_EmitsProjectFunded() public {
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    vm.expectEmit(true, true, false, true);
    emit ProjectFunded(projectId, investor1, 500, 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();
  }

  function test_FundProject_SharesBalanceUpdated() public {
    // Verifies ERC-1155 tokens are minted to the investor after funding
    projectId = _createProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();
    assertEq(solarProject.balanceOf(investor1, projectId), 500);
  }

  /*//////////////////////////////////////////////////////////////
                             BUYOUT TESTS
    //////////////////////////////////////////////////////////////*/

  function test_RevertWhen_BuyoutBeforeProjectFunded() public {
    projectId = _createProject();
    vm.prank(host);
    vm.expectRevert(SolarProject.NotInActiveStatus.selector);
    solarProject.triggerBuyout(projectId, 20_000 * 10 ** 6);
  }

  function test_HostCanTriggerBuyout() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 20_000 * 10 ** 6;

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
    assertTrue(project.isBoughtOut);
  }

  function test_BuyoutAtMonth0HostGets0Percent() public {
    projectId = _setupFullProject();
    // At month 0: host 0%, investors 100%
    uint256 offerAmount = 10_000 * 10 ** 6;
    uint256 hostBalanceBefore = usdc.balanceOf(host);

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    // Host paid offerAmount but gets 0% back (currentMonth=0)
    assertEq(usdc.balanceOf(host), hostBalanceBefore - offerAmount);
  }

  function test_BuyoutStatusChangeTosBoughtOut() public {
    projectId = _setupFullProject();
    vm.startPrank(host);
    usdc.approve(address(solarProject), 20_000 * 10 ** 6);
    solarProject.triggerBuyout(projectId, 20_000 * 10 ** 6);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
  }

  function test_BuyoutEmitsBuyoutTriggered() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 20_000 * 10 ** 6;

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    vm.expectEmit(true, false, false, false);
    emit BuyoutTriggered(projectId, offerAmount, 0, offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();
  }

  function test_InvestorCanClaimBuyoutProRata() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 10_000 * 10 ** 6;

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    // investor1 has 500/1000 = 50% of shares
    uint256 balanceBefore = usdc.balanceOf(investor1);
    vm.prank(investor1);
    solarProject.claimBuyout(projectId);
    uint256 balanceAfter = usdc.balanceOf(investor1);

    // investor1 should get 50% of 100% investor share = 50% of offerAmount
    assertEq(balanceAfter - balanceBefore, offerAmount / 2);
  }

  function test_OnlyHostOrLoanManagerCanTriggerBuyout() public {
    projectId = _setupFullProject();
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    vm.expectRevert(SolarProject.OnlyHostOrLoanManager.selector);
    solarProject.triggerBuyout(projectId, 10_000 * 10 ** 6);
    vm.stopPrank();
  }

  function test_GetTotalShares() public {
    projectId = _createProject();
    assertEq(solarProject.getTotalShares(projectId), TOTAL_SHARES);
  }

  // loanManager == address(0) branch in withdrawFunds
  function test_RevertWhen_WithdrawFundsWhenLoanManagerNotSet() public {
    // Deploy a fresh SolarProject with no loanManager set
    SolarProject freshSolar = new SolarProject(address(usdc));

    vm.prank(host);
    uint256 pid = freshSolar.initializeProject("Test", TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);

    // Fund it fully
    vm.startPrank(investor1);
    usdc.approve(address(freshSolar), TARGET_AMOUNT);
    freshSolar.fundProject(pid, TOTAL_SHARES);
    vm.stopPrank();

    vm.prank(host);
    vm.expectRevert(SolarProject.LoanManagerNotSet.selector);
    freshSolar.withdrawFunds(pid);
  }

  // setLoanManager "Already set" branch
  function test_RevertWhen_SetLoanManagerCalledTwice() public {
    // loanManager was already set in BaseTest.setUp()
    vm.expectRevert("Already set");
    solarProject.setLoanManager(address(loanManager));
  }

  // status == Defaulted branch in triggerBuyout (both Active and Defaulted are valid)
  function test_BuyoutFromDefaultedStatus() public {
    projectId = _setupFullProject();

    // Declare default (low rainfall)
    vm.warp(block.timestamp + 31 days);
    weatherOracle.setRainyDays(projectId, 0);
    loanManager.declareDefault(projectId);

    ISolarProject.Project memory p = solarProject.getProjectDetails(projectId);
    assertEq(uint256(p.status), uint256(ISolarProject.ProjectStatus.Defaulted));

    // Trigger buyout from Defaulted status — should NOT revert
    uint256 offerAmount = 10_000 * 10 ** 6;
    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    ISolarProject.Project memory after_ = solarProject.getProjectDetails(projectId);
    assertEq(uint256(after_.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
  }

  // hostAmount > 0 branch TRUE path (requires host equity > 0)
  function test_BuyoutHostReceivesShareAfterPayments() public {
    projectId = _setupFullProject();

    // Make 12 payments → hostPercent = 12*100/120 = 10%
    for (uint256 i = 0; i < 12; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();
      vm.warp(block.timestamp + 30 days);
    }

    uint256 offerAmount = 10_000 * 10 ** 6;
    uint256 expectedHostAmount = (offerAmount * 10) / 100; // 10%
    uint256 hostBalanceBefore = usdc.balanceOf(host);

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    // Host paid offerAmount out and got expectedHostAmount back
    assertEq(usdc.balanceOf(host), hostBalanceBefore - offerAmount + expectedHostAmount);
  }

  // investorAmount == 0 branch FALSE path in _distributeBuyoutToInvestors
  function test_BuyoutWithZeroOfferDistributesNothing() public {
    projectId = _setupFullProject();

    // Zero offer → both hostAmount and investorAmount are 0
    // Tests: if (hostAmount > 0) → FALSE, if (totalShares > 0 && investorAmount > 0) → FALSE
    vm.startPrank(host);
    usdc.approve(address(solarProject), 0);
    solarProject.triggerBuyout(projectId, 0);
    vm.stopPrank();

    ISolarProject.Project memory p = solarProject.getProjectDetails(projectId);
    assertEq(uint256(p.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
    assertEq(solarProject.buyoutPerShare(projectId), 0);
  }

  // claimable == 0 branch in claimBuyout (totalOwed <= claimed)
  function test_RevertWhen_ClaimBuyoutWithNoShares() public {
    projectId = _setupFullProject();

    uint256 offerAmount = 10_000 * 10 ** 6;
    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    // Non-investor has 0 shares → totalOwed = 0, claimed = 0 → claimable = 0
    address nonInvestor = makeAddr("nonInvestor");
    vm.prank(nonInvestor);
    vm.expectRevert("Nothing to claim");
    solarProject.claimBuyout(projectId);
  }

  // getProjectHost - untested view function
  function test_GetProjectHost() public {
    projectId = _createProject();
    assertEq(solarProject.getProjectHost(projectId), host);
  }

  // completeProject - success path (called by loanManager)
  function test_CompleteProject_ByLoanManager() public {
    projectId = _setupFullProject();
    vm.prank(address(loanManager));
    solarProject.completeProject(projectId);
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
  }

  // completeProject - revert when unauthorized
  function test_RevertWhen_CompleteProjectUnauthorized() public {
    projectId = _setupFullProject();
    vm.prank(investor1);
    vm.expectRevert("Unauthorized");
    solarProject.completeProject(projectId);
  }

  // setProjectDefaulted - success path (called by loanManager)
  function test_SetProjectDefaulted_ByLoanManager() public {
    projectId = _setupFullProject();
    vm.prank(address(loanManager));
    solarProject.setProjectDefaulted(projectId);
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Defaulted));
  }

  // setProjectDefaulted - revert when unauthorized
  function test_RevertWhen_SetProjectDefaultedUnauthorized() public {
    projectId = _setupFullProject();
    vm.prank(investor1);
    vm.expectRevert(SolarProject.OnlyLoanManager.selector);
    solarProject.setProjectDefaulted(projectId);
  }

  // withdrawFunds - revert when caller is not host
  function test_RevertWhen_WithdrawFundsNotHost() public {
    projectId = _fundProjectFully();
    vm.prank(investor1);
    vm.expectRevert(SolarProject.OnlyHostOrLoanManager.selector);
    solarProject.withdrawFunds(projectId);
  }

  // withdrawFunds - revert when project not fully funded
  function test_RevertWhen_WithdrawFundsNotFullyFunded() public {
    projectId = _createProject();
    // Partially fund the project
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();

    vm.prank(host);
    vm.expectRevert(SolarProject.ProjectNotFullyFunded.selector);
    solarProject.withdrawFunds(projectId);
  }

  // fundProject - NotInFundingStatus when project is Active
  function test_RevertWhen_FundProjectAfterActive() public {
    projectId = _setupFullProject(); // now status = Active
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 20 * 10 ** 6);
    vm.expectRevert(SolarProject.NotInFundingStatus.selector);
    solarProject.fundProject(projectId, 1);
    vm.stopPrank();
  }

  // triggerBuyout - called by loanManager (not host)
  function test_BuyoutTriggeredByLoanManager() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 10_000 * 10 ** 6;

    // Fund loanManager with USDC to pay buyout
    _fundUser(address(loanManager), offerAmount);
    vm.startPrank(address(loanManager));
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
  }

  // claimBuyout - double claim reverts (totalOwed <= claimed)
  function test_RevertWhen_ClaimBuyoutTwice() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 10_000 * 10 ** 6;

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    // First claim succeeds
    vm.prank(investor1);
    solarProject.claimBuyout(projectId);

    // Second claim reverts — tokens burned, nothing to claim
    vm.prank(investor1);
    vm.expectRevert("Nothing to claim");
    solarProject.claimBuyout(projectId);
  }

  // withdrawFunds emits FundsWithdrawn event
  function test_WithdrawFunds_EmitsFundsWithdrawn() public {
    projectId = _fundProjectFully();
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(host);
    vm.expectEmit(true, true, false, true);
    emit FundsWithdrawn(projectId, host, TARGET_AMOUNT);
    solarProject.withdrawFunds(projectId);
  }

  // setProjectDefaulted emits ProjectStatusChanged event
  function test_SetProjectDefaulted_EmitsEvent() public {
    projectId = _setupFullProject();
    vm.prank(address(loanManager));
    vm.expectEmit(true, false, false, true);
    emit ProjectStatusChanged(projectId, ISolarProject.ProjectStatus.Defaulted);
    solarProject.setProjectDefaulted(projectId);
  }

  // Multiple investors all claim buyout proportionally
  function test_AllInvestorsClaimBuyoutProRata() public {
    projectId = _setupFullProject();
    uint256 offerAmount = 10_000 * 10 ** 6;

    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    uint256 before1 = usdc.balanceOf(investor1);
    uint256 before2 = usdc.balanceOf(investor2);
    uint256 before3 = usdc.balanceOf(investor3);

    vm.prank(investor1);
    solarProject.claimBuyout(projectId);
    vm.prank(investor2);
    solarProject.claimBuyout(projectId);
    vm.prank(investor3);
    solarProject.claimBuyout(projectId);

    // investor1=500/1000=50%, investor2=300/1000=30%, investor3=200/1000=20%
    assertApproxEqAbs(usdc.balanceOf(investor1) - before1, (offerAmount * 50) / 100, 1);
    assertApproxEqAbs(usdc.balanceOf(investor2) - before2, (offerAmount * 30) / 100, 1);
    assertApproxEqAbs(usdc.balanceOf(investor3) - before3, (offerAmount * 20) / 100, 1);
  }
}
