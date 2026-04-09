// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {ISolarProject} from "../../src/interfaces/ISolarProject.sol";
import {MaintenanceDAO} from "../../src/core/MaintenanceDAO.sol";

contract FullSystemTest is BaseTest {
  /*//////////////////////////////////////////////////////////////
                    TEST 1: HAPPY PATH FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

  function test_FullLifecycle_HappyPath() public {
    // 1. Host mints SBT
    vm.prank(host);
    reputation.mintSbt(host);
    assertEq(reputation.getScore(host), 1000);

    // 2. Host creates project ($20,000, 120 months, 1000 shares)
    vm.prank(host);
    uint256 projectId = solarProject.initializeProject(
      "Solar Demo",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );

    // 3. Three investors fund project
    vm.startPrank(investor1);
    usdc.approve(address(solarProject), 10_000 * 10 ** 6);
    solarProject.fundProject(projectId, 500);
    vm.stopPrank();

    vm.startPrank(investor2);
    usdc.approve(address(solarProject), 6_000 * 10 ** 6);
    solarProject.fundProject(projectId, 300);
    vm.stopPrank();

    vm.startPrank(investor3);
    usdc.approve(address(solarProject), 4_000 * 10 ** 6);
    solarProject.fundProject(projectId, 200);
    vm.stopPrank();

    // Trigger transition to Active and initialize loan via withdrawal
    vm.prank(host);
    solarProject.withdrawFunds(projectId);

    // Verify: project fully funded and active
    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertTrue(project.isFunded);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Active));

    // === MONTH 1 ===

    // 4. Host pays monthly installment
    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    // 5. Oracle deposits $80 grid revenue (FIXED: Pranking gridOracle)
    uint256 gridRevenue = 80 * 10 ** 6;
    vm.startPrank(address(gridOracle));
    usdc.mint(address(gridOracle), gridRevenue);
    usdc.approve(address(distributor), gridRevenue);
    distributor.depositGridRevenue(projectId, gridRevenue);
    vm.stopPrank();

    // 6. Execute waterfall: $280 total
    distributor.executeWaterfall(projectId);

    uint256 totalMonth1 = MONTHLY_PAYMENT + gridRevenue;
    uint256 dividendMonth1 = (totalMonth1 * 93) / 100;

    // 7. Investor A claims dividends (50%)
    uint256 bal1Before = usdc.balanceOf(investor1);
    vm.prank(investor1);
    distributor.claimDividends(projectId);
    uint256 claimed1 = usdc.balanceOf(investor1) - bal1Before;
    assertEq(claimed1, dividendMonth1 / 2);

    // 8. Investor B claims (30%)
    uint256 bal2Before = usdc.balanceOf(investor2);
    vm.prank(investor2);
    distributor.claimDividends(projectId);
    uint256 claimed2 = usdc.balanceOf(investor2) - bal2Before;
    assertEq(claimed2, (dividendMonth1 * 30) / 100);

    // 9. Investor C claims (20%)
    uint256 bal3Before = usdc.balanceOf(investor3);
    vm.prank(investor3);
    distributor.claimDividends(projectId);
    uint256 claimed3 = usdc.balanceOf(investor3) - bal3Before;
    assertEq(claimed3, (dividendMonth1 * 20) / 100);

    // === MONTH 2 ===
    vm.warp(block.timestamp + 30 days);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    uint256 gridRevenue2 = 120 * 10 ** 6;
    vm.startPrank(address(gridOracle)); // FIXED: Pranking gridOracle
    usdc.mint(address(gridOracle), gridRevenue2);
    usdc.approve(address(distributor), gridRevenue2);
    distributor.depositGridRevenue(projectId, gridRevenue2);
    vm.stopPrank();

    distributor.executeWaterfall(projectId);

    uint256 totalMonth2 = MONTHLY_PAYMENT + gridRevenue2;
    uint256 dividendMonth2 = (totalMonth2 * 93) / 100;

    uint256 bal1Month2 = usdc.balanceOf(investor1);
    vm.prank(investor1);
    distributor.claimDividends(projectId);
    uint256 claimedMonth2 = usdc.balanceOf(investor1) - bal1Month2;
    assertEq(claimedMonth2, dividendMonth2 / 2);

    // Verify equity split
    (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPct, 1);
    assertEq(investorPct, 99);

    // Host reputation unchanged
    assertEq(reputation.getScore(host), 1000);
  }

  /*//////////////////////////////////////////////////////////////
                        TEST 2: DEFAULT SCENARIO
    //////////////////////////////////////////////////////////////*/

  function test_DefaultScenario() public {
    uint256 projectId = _setupFullProject();

    deal(address(usdc), address(dao), 1000 * 10 ** 6);

    vm.prank(host);
    reputation.mintSbt(host);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    vm.warp(block.timestamp + 61 days);

    assertTrue(loanManager.checkDefaultStatus(projectId));

    loanManager.declareDefault(projectId);

    assertTrue(iotOracle.isKillswitchActive(projectId), "Hardware should be LOCKED after default");

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Defaulted));

    assertEq(reputation.getScore(host), 800);

    vm.startPrank(host);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    vm.expectRevert();
    loanManager.payMonthlyInstallment(projectId);
    vm.stopPrank();

    uint256 offerAmount = 15_000 * 10 ** 6;
    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPct, 0);
    assertEq(investorPct, 100);

    uint256 bal1Before = usdc.balanceOf(investor1);
    vm.prank(investor1);
    solarProject.claimBuyout(projectId);
    uint256 investor1Received = usdc.balanceOf(investor1) - bal1Before;
    assertEq(investor1Received, offerAmount / 2);

    ISolarProject.Project memory projectAfter = solarProject.getProjectDetails(projectId);
    assertEq(uint256(projectAfter.status), uint256(ISolarProject.ProjectStatus.BoughtOut));
  }

  /*//////////////////////////////////////////////////////////////
                   TEST 3: MULTI-MONTH ACCUMULATION
    //////////////////////////////////////////////////////////////*/

  function test_MultiMonthAccumulation() public {
    uint256 projectId = _setupFullProject();

    uint256 monthlyRevenue = 100 * 10 ** 6;
    uint256 totalDividendForInvestor1;

    for (uint256 i = 0; i < 5; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();

      vm.startPrank(address(gridOracle)); // FIXED: Pranking gridOracle
      usdc.mint(address(gridOracle), monthlyRevenue);
      usdc.approve(address(distributor), monthlyRevenue);
      distributor.depositGridRevenue(projectId, monthlyRevenue);
      vm.stopPrank();

      distributor.executeWaterfall(projectId);

      uint256 total = MONTHLY_PAYMENT + monthlyRevenue;
      uint256 dividend = (total * 93) / 100;
      totalDividendForInvestor1 += dividend / 2;

      vm.warp(block.timestamp + 30 days);
    }

    uint256 claimable = distributor.getClaimableDividends(projectId, investor1);
    assertEq(claimable, totalDividendForInvestor1);

    uint256 balBefore = usdc.balanceOf(investor1);
    vm.prank(investor1);
    distributor.claimDividends(projectId);
    assertEq(usdc.balanceOf(investor1) - balBefore, totalDividendForInvestor1);
  }

  /*//////////////////////////////////////////////////////////////
                     TEST 4: MULTIPLE PROJECTS
    //////////////////////////////////////////////////////////////*/

  function test_MultipleProjects() public {
    address hostA = makeAddr("hostA");
    address hostB = makeAddr("hostB");
    vm.prank(owner);
    usdc.mint(hostA, INITIAL_USDC);
    vm.prank(owner);
    usdc.mint(hostB, INITIAL_USDC);

    vm.prank(hostA);
    uint256 projectId1 = solarProject.initializeProject(
      "Solar Demo",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );

    vm.prank(hostB);
    uint256 projectId2 = solarProject.initializeProject(
      "Solar Demo",
      TARGET_AMOUNT,
      TERM_MONTHS,
      TOTAL_SHARES
    );

    vm.startPrank(investor1);
    usdc.approve(address(solarProject), TARGET_AMOUNT * 2);
    solarProject.fundProject(projectId1, TOTAL_SHARES);
    vm.stopPrank();

    vm.startPrank(investor2);
    usdc.approve(address(solarProject), TARGET_AMOUNT * 2);
    solarProject.fundProject(projectId2, TOTAL_SHARES);
    vm.stopPrank();

    vm.prank(hostA);
    solarProject.withdrawFunds(projectId1);
    vm.prank(hostB);
    solarProject.withdrawFunds(projectId2);

    vm.startPrank(hostA);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId1);
    vm.stopPrank();

    vm.startPrank(hostB);
    usdc.approve(address(loanManager), MONTHLY_PAYMENT);
    loanManager.payMonthlyInstallment(projectId2);
    vm.stopPrank();

    distributor.executeWaterfall(projectId1);
    distributor.executeWaterfall(projectId2);

    uint256 claimable1 = distributor.getClaimableDividends(projectId1, investor1);
    uint256 claimable2 = distributor.getClaimableDividends(projectId2, investor1);

    assertGt(claimable1, 0);
    assertEq(claimable2, 0);

    uint256 claimable2ForInvestor2 = distributor.getClaimableDividends(projectId2, investor2);
    assertGt(claimable2ForInvestor2, 0);

    assertEq(loanManager.getCurrentMonth(projectId1), 1);
    assertEq(loanManager.getCurrentMonth(projectId2), 1);
  }

  /*//////////////////////////////////////////////////////////////
                      TEST 5: BUYOUT AT MONTH 60
    //////////////////////////////////////////////////////////////*/

  function test_BuyoutAtMonth60() public {
    uint256 projectId = _setupFullProject();

    for (uint256 i = 0; i < 60; i++) {
      vm.startPrank(host);
      usdc.approve(address(loanManager), MONTHLY_PAYMENT);
      loanManager.payMonthlyInstallment(projectId);
      vm.stopPrank();

      distributor.executeWaterfall(projectId);

      vm.warp(block.timestamp + 30 days);
    }

    (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
    assertEq(hostPct, 50);
    assertEq(investorPct, 50);

    uint256 offerAmount = 15_000 * 10 ** 6;
    vm.startPrank(host);
    usdc.approve(address(solarProject), offerAmount);
    solarProject.triggerBuyout(projectId, offerAmount);
    vm.stopPrank();

    ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
    assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));

    uint256 bal1Before = usdc.balanceOf(investor1);
    vm.prank(investor1);
    solarProject.claimBuyout(projectId);
    uint256 investor1Got = usdc.balanceOf(investor1) - bal1Before;
    assertEq(investor1Got, (offerAmount * 50 * 50) / (100 * 100));

    uint256 bal2Before = usdc.balanceOf(investor2);
    vm.prank(investor2);
    solarProject.claimBuyout(projectId);
    uint256 investor2Got = usdc.balanceOf(investor2) - bal2Before;
    assertEq(investor2Got, (offerAmount * 50 * 30) / (100 * 100));
  }

  /*//////////////////////////////////////////////////////////////
                TEST 6: GOVERNANCE PROPOSAL - PASSED
    //////////////////////////////////////////////////////////////*/

  function test_GovernanceProposal_Passed() public {
    uint256 projectId = _setupFullProject();

    _generateMaintenanceReserve(projectId, 10_000 * 10 ** 6);
    uint256 reserveBalance = distributor.getMaintenanceReserve(projectId);
    assertTrue(reserveBalance >= 500 * 10 ** 6);

    address vendorAddr = makeAddr("vendor");
    uint256 proposalAmount = 500 * 10 ** 6;
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Replace damaged inverter",
      proposalAmount,
      payable(vendorAddr)
    );

    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);
    vm.prank(investor3);
    dao.castVote(proposalId, false);

    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(p.yesVotes, 800);
    assertEq(p.noVotes, 200);

    vm.warp(block.timestamp + 7 days + 1);

    uint256 vendorBalanceBefore = usdc.balanceOf(vendorAddr);
    dao.executeProposal(proposalId);

    MaintenanceDAO.Proposal memory executed = dao.getProposal(proposalId);
    assertEq(uint8(executed.status), uint8(MaintenanceDAO.ProposalStatus.Executed));
    assertTrue(executed.passed);
    assertEq(usdc.balanceOf(vendorAddr) - vendorBalanceBefore, proposalAmount);
    assertEq(distributor.getMaintenanceReserve(projectId), reserveBalance - proposalAmount);
  }

  /*//////////////////////////////////////////////////////////////
                TEST 7: GOVERNANCE PROPOSAL - REJECTED
    //////////////////////////////////////////////////////////////*/

  function test_GovernanceProposal_Rejected() public {
    uint256 projectId = _setupFullProject();
    _generateMaintenanceReserve(projectId, 10_000 * 10 ** 6);
    uint256 reserveBefore = distributor.getMaintenanceReserve(projectId);

    address vendorAddr = makeAddr("vendor");
    uint256 proposalAmount = 500 * 10 ** 6;
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Replace inverter",
      proposalAmount,
      payable(vendorAddr)
    );

    vm.prank(investor1);
    dao.castVote(proposalId, false);
    vm.prank(investor2);
    dao.castVote(proposalId, true);
    vm.prank(investor3);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(uint8(p.status), uint8(MaintenanceDAO.ProposalStatus.Rejected));
    assertEq(p.yesVotes, 500);
    assertEq(usdc.balanceOf(vendorAddr), 0);
    assertEq(distributor.getMaintenanceReserve(projectId), reserveBefore);
  }

  /*//////////////////////////////////////////////////////////////
                TEST 8: MULTIPLE PROPOSALS
    //////////////////////////////////////////////////////////////*/

  function test_MultipleProposals() public {
    uint256 projectId = _setupFullProject();
    _generateMaintenanceReserve(projectId, 20_000 * 10 ** 6);

    address vendorAddr = makeAddr("vendor");
    uint256 amt1 = 300 * 10 ** 6;
    uint256 amt2 = 400 * 10 ** 6;

    vm.prank(investor1);
    uint256 p1 = dao.submitProposal(projectId, "Panel cleaning", amt1, payable(vendorAddr));
    vm.prank(investor1);
    uint256 p2 = dao.submitProposal(projectId, "Wiring repair", amt2, payable(vendorAddr));

    vm.prank(investor1);
    dao.castVote(p1, true);
    vm.prank(investor2);
    dao.castVote(p1, true);
    vm.prank(investor1);
    dao.castVote(p2, true);
    vm.prank(investor2);
    dao.castVote(p2, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(p1);
    dao.executeProposal(p2);

    assertEq(uint8(dao.getProposal(p1).status), uint8(MaintenanceDAO.ProposalStatus.Executed));
    assertEq(uint8(dao.getProposal(p2).status), uint8(MaintenanceDAO.ProposalStatus.Executed));
    assertEq(usdc.balanceOf(vendorAddr), amt1 + amt2);
  }

  /*//////////////////////////////////////////////////////////////
                TEST 9: BAD WEATHER BYPASS
    //////////////////////////////////////////////////////////////*/

  function testParametricPayoutBypass() public {
    uint256 projectId = _setupFullProject();

    _generateMaintenanceReserve(projectId, 10_000 * 10 ** 6);

    address vendorAddr = makeAddr("bypass_vendor");

    vm.prank(host);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Emergency",
      500 * 10 ** 6,
      payable(vendorAddr)
    );

    vm.prank(address(weatherOracle));
    weatherOracle.setRainyDays(projectId, 20);

    dao.executeProposal(proposalId);

    assertEq(usdc.balanceOf(vendorAddr), 500 * 10 ** 6);
  }

  /*//////////////////////////////////////////////////////////////
                UTILITY: GENERATE RESERVE (FIXED)
    //////////////////////////////////////////////////////////////*/

  function _generateMaintenanceReserve(uint256 _projectId, uint256 _amount) internal override {
    // FIXED: All DAO tests that need maintenance funds now use the authorized Oracle identity
    vm.startPrank(address(gridOracle));
    usdc.mint(address(gridOracle), _amount);
    usdc.approve(address(distributor), _amount);
    distributor.depositGridRevenue(_projectId, _amount);
    distributor.executeWaterfall(_projectId);
    vm.stopPrank();
  }
}
