// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {ISolarProject} from "../../src/interfaces/ISolarProject.sol";
import {SolarProject} from "../../src/core/SolarProject.sol";

contract SolarProjectTest is BaseTest {
    // Re-declare events for expectEmit
    event ProjectCreated(uint256 indexed projectId, address indexed host, uint256 targetAmount, uint256 termMonths);
    event ProjectFunded(uint256 indexed projectId, address indexed investor, uint256 numShares, uint256 amount);
    event SharesMinted(uint256 indexed projectId, address indexed investor, uint256 numShares);
    event BuyoutTriggered(uint256 indexed projectId, uint256 offerAmount, uint256 hostShare, uint256 investorShare);

    uint256 public projectId;

    /*//////////////////////////////////////////////////////////////
                           INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitializeProject() public {
        vm.prank(host);
        projectId = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);

        ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
        assertEq(project.host, host);
        assertEq(project.targetAmount, TARGET_AMOUNT);
        assertEq(project.termMonths, TERM_MONTHS);
        assertEq(project.totalShares, TOTAL_SHARES);
        assertEq(project.amountRaised, 0);
        assertEq(project.sharesSold, 0);
    }

    function test_ProjectIdIncrements() public {
        vm.startPrank(host);
        uint256 id1 = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
        uint256 id2 = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
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
        solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
    }

    function test_RevertWhen_InitializeWithZeroTargetAmount() public {
        vm.prank(host);
        vm.expectRevert(SolarProject.InvalidTargetAmount.selector);
        solarProject.initializeProject(0, TERM_MONTHS, TOTAL_SHARES);
    }

    function test_RevertWhen_InitializeWithZeroTermMonths() public {
        vm.prank(host);
        vm.expectRevert(SolarProject.InvalidTermMonths.selector);
        solarProject.initializeProject(TARGET_AMOUNT, 0, TOTAL_SHARES);
    }

    function test_RevertWhen_InitializeWithZeroTotalShares() public {
        vm.prank(host);
        vm.expectRevert(SolarProject.InvalidTotalShares.selector);
        solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, 0);
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
        vm.startPrank(investor1);
        usdc.approve(address(solarProject), 20 * 10 ** 6);
        vm.expectRevert(SolarProject.NotInFundingStatus.selector);
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

    function test_FundProject_EmitsSharesMinted() public {
        projectId = _createProject();
        vm.startPrank(investor1);
        usdc.approve(address(solarProject), 10_000 * 10 ** 6);
        vm.expectEmit(true, true, false, true);
        emit SharesMinted(projectId, investor1, 500);
        solarProject.fundProject(projectId, 500);
        vm.stopPrank();
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
}
