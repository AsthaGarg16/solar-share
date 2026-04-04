// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { ISolarProject } from "../../src/interfaces/ISolarProject.sol";
import { MaintenanceDAO } from "../../src/core/MaintenanceDAO.sol";

contract FullSystemTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                    TEST 1: HAPPY PATH FULL LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function test_FullLifecycle_HappyPath() public {
        // 1. Host mints SBT
        vm.prank(host);
        reputation.mintSBT(host);
        assertEq(reputation.getScore(host), 1000);

        // 2. Host creates project ($20,000, 120 months, 1000 shares)
        vm.prank(host);
        uint256 projectId = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);

        // 3. Three investors fund project
        vm.startPrank(investor1); // 500 shares = 50%
        usdc.approve(address(solarProject), 10_000 * 10 ** 6);
        solarProject.fundProject(projectId, 500);
        vm.stopPrank();

        vm.startPrank(investor2); // 300 shares = 30%
        usdc.approve(address(solarProject), 6_000 * 10 ** 6);
        solarProject.fundProject(projectId, 300);
        vm.stopPrank();

        vm.startPrank(investor3); // 200 shares = 20%
        usdc.approve(address(solarProject), 4_000 * 10 ** 6);
        solarProject.fundProject(projectId, 200);
        vm.stopPrank();

        // Verify: project fully funded and active
        ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
        assertTrue(project.isFunded);
        assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Active));

        // 4. Host withdraws funds (auto-initializes loan, first payment due in 30 days)
        vm.prank(host);
        solarProject.withdrawFunds(projectId);

        // === MONTH 1 ===

        // 5. Host pays $200
        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();

        // 6. Oracle deposits $80 grid revenue
        uint256 gridRevenue = 80 * 10 ** 6;
        vm.startPrank(owner);
        usdc.mint(owner, gridRevenue);
        usdc.approve(address(distributor), gridRevenue);
        distributor.depositGridRevenue(projectId, gridRevenue);
        vm.stopPrank();

        // 7. Execute waterfall: $280 total
        distributor.executeWaterfall(projectId);

        uint256 totalMonth1 = MONTHLY_PAYMENT + gridRevenue; // $280
        uint256 dividendMonth1 = (totalMonth1 * 93) / 100; // $260.40

        // 8. Investor A claims dividends (50%)
        uint256 bal1Before = usdc.balanceOf(investor1);
        vm.prank(investor1);
        distributor.claimDividends(projectId);
        uint256 claimed1 = usdc.balanceOf(investor1) - bal1Before;
        assertEq(claimed1, dividendMonth1 / 2); // 50%

        // 9. Investor B claims (30%)
        uint256 bal2Before = usdc.balanceOf(investor2);
        vm.prank(investor2);
        distributor.claimDividends(projectId);
        uint256 claimed2 = usdc.balanceOf(investor2) - bal2Before;
        assertEq(claimed2, (dividendMonth1 * 30) / 100); // 30%

        // 10. Investor C claims (20%)
        uint256 bal3Before = usdc.balanceOf(investor3);
        vm.prank(investor3);
        distributor.claimDividends(projectId);
        uint256 claimed3 = usdc.balanceOf(investor3) - bal3Before;
        assertEq(claimed3, (dividendMonth1 * 20) / 100); // 20%

        // === MONTH 2 ===
        vm.warp(block.timestamp + 30 days);

        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();

        uint256 gridRevenue2 = 120 * 10 ** 6;
        vm.startPrank(owner);
        usdc.mint(owner, gridRevenue2);
        usdc.approve(address(distributor), gridRevenue2);
        distributor.depositGridRevenue(projectId, gridRevenue2);
        vm.stopPrank();

        distributor.executeWaterfall(projectId);

        uint256 totalMonth2 = MONTHLY_PAYMENT + gridRevenue2; // $320
        uint256 dividendMonth2 = (totalMonth2 * 93) / 100;

        uint256 bal1Month2 = usdc.balanceOf(investor1);
        vm.prank(investor1);
        distributor.claimDividends(projectId);
        uint256 claimedMonth2 = usdc.balanceOf(investor1) - bal1Month2;
        assertApproxEqAbs(claimedMonth2, dividendMonth2 / 2, 1); // Month 2 only (month 1 already claimed); ±1 wei precision

        // Verify equity split
        (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
        assertEq(hostPct, 1); // 2 * 100 / 120 = 1 (integer)
        assertEq(investorPct, 99);

        // Host reputation unchanged
        assertEq(reputation.getScore(host), 1000);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST 2: DEFAULT SCENARIO
    //////////////////////////////////////////////////////////////*/

    function test_DefaultScenario() public {
        // Setup: project funded and active
        uint256 projectId = _setupFullProject();
        // Host needs SBT for slashing on default
        vm.prank(host);
        reputation.mintSBT(host);

        // Month 1: Host pays on time
        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();

        // Month 2: Host does NOT pay — warp past nextPaymentDue (initial + 30d payment + 30d grace)
        vm.warp(block.timestamp + 61 days);

        // Check default status
        assertTrue(loanManager.checkDefaultStatus(projectId));

        // Keeper declares default
        loanManager.declareDefault(projectId);

        // Project defaulted
        ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
        assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.Defaulted));

        // Reputation slashed
        assertEq(reputation.getScore(host), 800); // 1000 - 200

        // Cannot make further payments
        vm.startPrank(host);
        usdc.approve(address(loanManager), MONTHLY_PAYMENT);
        vm.expectRevert();
        loanManager.payMonthlyInstallment(projectId);
        vm.stopPrank();

        // Trigger buyout (host triggers even after default since project is Defaulted status)
        uint256 offerAmount = 15_000 * 10 ** 6;
        vm.startPrank(host);
        usdc.approve(address(solarProject), offerAmount);
        solarProject.triggerBuyout(projectId, offerAmount);
        vm.stopPrank();

        // Equity split at month 1: 1 * 100 / 120 = 0% host, 100% investors
        (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
        assertEq(hostPct, 0);
        assertEq(investorPct, 100);

        // Investors can claim buyout proceeds
        uint256 bal1Before = usdc.balanceOf(investor1);
        vm.prank(investor1);
        solarProject.claimBuyout(projectId);
        uint256 investor1Received = usdc.balanceOf(investor1) - bal1Before;
        assertEq(investor1Received, offerAmount / 2); // 50% of investor portion

        // Project status is BoughtOut
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

        // Months 1-5: host pays, oracle deposits, waterfall executes
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(host);
            usdc.approve(address(loanManager), MONTHLY_PAYMENT);
            loanManager.payMonthlyInstallment(projectId);
            vm.stopPrank();

            vm.startPrank(owner);
            usdc.mint(owner, monthlyRevenue);
            usdc.approve(address(distributor), monthlyRevenue);
            distributor.depositGridRevenue(projectId, monthlyRevenue);
            vm.stopPrank();

            distributor.executeWaterfall(projectId);

            uint256 total = MONTHLY_PAYMENT + monthlyRevenue;
            uint256 dividend = (total * 93) / 100;
            totalDividendForInvestor1 += dividend / 2; // investor1 has 50%

            vm.warp(block.timestamp + 30 days);
        }

        // Investor1 has NOT claimed for 5 months - claims all at once
        uint256 claimable = distributor.getClaimableDividends(projectId, investor1);
        assertApproxEqAbs(claimable, totalDividendForInvestor1, 5); // ±5 wei precision over 5 months

        uint256 balBefore = usdc.balanceOf(investor1);
        vm.prank(investor1);
        distributor.claimDividends(projectId); // O(1) gas regardless of months
        assertApproxEqAbs(usdc.balanceOf(investor1) - balBefore, totalDividendForInvestor1, 5);
    }

    /*//////////////////////////////////////////////////////////////
                     TEST 4: MULTIPLE PROJECTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleProjects() public {
        // Host A creates Project 1
        address hostA = makeAddr("hostA");
        address hostB = makeAddr("hostB");
        vm.prank(owner);
        usdc.mint(hostA, INITIAL_USDC);
        vm.prank(owner);
        usdc.mint(hostB, INITIAL_USDC);

        vm.prank(hostA);
        uint256 projectId1 =
            solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);

        vm.prank(hostB);
        uint256 projectId2 =
            solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);

        // Fund both projects
        vm.startPrank(investor1);
        usdc.approve(address(solarProject), TARGET_AMOUNT * 2);
        solarProject.fundProject(projectId1, TOTAL_SHARES);
        vm.stopPrank();

        vm.startPrank(investor2);
        usdc.approve(address(solarProject), TARGET_AMOUNT * 2);
        solarProject.fundProject(projectId2, TOTAL_SHARES);
        vm.stopPrank();

        // Hosts withdraw funds (auto-initializes loans)
        vm.prank(hostA);
        solarProject.withdrawFunds(projectId1);
        vm.prank(hostB);
        solarProject.withdrawFunds(projectId2);

        // Both hosts make payments
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

        // Dividends don't mix between projects
        uint256 claimable1 = distributor.getClaimableDividends(projectId1, investor1);
        uint256 claimable2 = distributor.getClaimableDividends(projectId2, investor1);

        assertGt(claimable1, 0);
        assertEq(claimable2, 0); // investor1 has no shares in project2

        uint256 claimable2ForInvestor2 = distributor.getClaimableDividends(projectId2, investor2);
        assertGt(claimable2ForInvestor2, 0);

        // Each project has isolated state
        assertEq(loanManager.getCurrentMonth(projectId1), 1);
        assertEq(loanManager.getCurrentMonth(projectId2), 1);
    }

    /*//////////////////////////////////////////////////////////////
                      TEST 5: BUYOUT AT MONTH 60
    //////////////////////////////////////////////////////////////*/

    function test_BuyoutAtMonth60() public {
        uint256 projectId = _setupFullProject();

        // Make 60 payments
        for (uint256 i = 0; i < 60; i++) {
            vm.startPrank(host);
            usdc.approve(address(loanManager), MONTHLY_PAYMENT);
            loanManager.payMonthlyInstallment(projectId);
            vm.stopPrank();

            // Execute waterfall each month
            distributor.executeWaterfall(projectId);

            vm.warp(block.timestamp + 30 days);
        }

        // Equity split at month 60: 50% host, 50% investors
        (uint256 hostPct, uint256 investorPct) = loanManager.calculateEquitySplit(projectId);
        assertEq(hostPct, 50);
        assertEq(investorPct, 50);

        // Host triggers buyout with $15,000 offer
        uint256 offerAmount = 15_000 * 10 ** 6;
        vm.startPrank(host);
        usdc.approve(address(solarProject), offerAmount);
        solarProject.triggerBuyout(projectId, offerAmount);
        vm.stopPrank();

        // Project status = BoughtOut
        ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
        assertEq(uint256(project.status), uint256(ISolarProject.ProjectStatus.BoughtOut));

        // Investors claim buyout (50% of 50% investor share)
        // investor1 has 50% shares -> gets 50% of investorAmount = 50% of ($15,000 * 50%) = $3,750
        uint256 bal1Before = usdc.balanceOf(investor1);
        vm.prank(investor1);
        solarProject.claimBuyout(projectId);
        uint256 investor1Got = usdc.balanceOf(investor1) - bal1Before;
        assertEq(investor1Got, (offerAmount * 50 / 100) * 50 / 100); // 50% of 50% = $3,750

        // investor2 has 30% shares -> 30% of investorAmount
        uint256 bal2Before = usdc.balanceOf(investor2);
        vm.prank(investor2);
        solarProject.claimBuyout(projectId);
        uint256 investor2Got = usdc.balanceOf(investor2) - bal2Before;
        assertEq(investor2Got, (offerAmount * 50 / 100) * 30 / 100);
    }

    /*//////////////////////////////////////////////////////////////
                TEST 6: GOVERNANCE PROPOSAL - PASSED
    //////////////////////////////////////////////////////////////*/

    function test_GovernanceProposal_Passed() public {
        // 1. Setup: Project active
        uint256 projectId = _setupFullProject();

        // 2. Generate $10,000 in revenue → $500 maintenance reserve (5%)
        _generateMaintenanceReserve(projectId, 10_000 * 10 ** 6);
        uint256 reserveBalance = distributor.getMaintenanceReserve(projectId);
        assertTrue(reserveBalance >= 500 * 10 ** 6);

        // 3. Submit repair proposal: $500 USDC
        address vendorAddr = makeAddr("vendor");
        uint256 proposalAmount = 500 * 10 ** 6;
        vm.prank(investor1);
        uint256 proposalId = dao.submitProposal(
            projectId, "Replace damaged inverter", proposalAmount, payable(vendorAddr)
        );

        // 4. Investors vote:
        // investor1 (500 tokens): YES
        // investor2 (300 tokens): YES
        // investor3 (200 tokens): NO
        vm.prank(investor1);
        dao.castVote(proposalId, true);
        vm.prank(investor2);
        dao.castVote(proposalId, true);
        vm.prank(investor3);
        dao.castVote(proposalId, false);

        MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
        assertEq(p.yesVotes, 800); // 500 + 300
        assertEq(p.noVotes, 200);

        // 5. Wait 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // 6. Execute proposal
        uint256 vendorBalanceBefore = usdc.balanceOf(vendorAddr);
        dao.executeProposal(proposalId);

        // 7. Assertions
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
            projectId, "Replace inverter", proposalAmount, payable(vendorAddr)
        );

        // investor1 (500 tokens): NO
        // investor2 (300 tokens): YES
        // investor3 (200 tokens): YES
        // Total YES = 500 = exactly 50%, NOT > 50%, so REJECTED
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
        _generateMaintenanceReserve(projectId, 20_000 * 10 ** 6); // $1,000 reserve

        address vendorAddr = makeAddr("vendor");
        uint256 amt1 = 300 * 10 ** 6;
        uint256 amt2 = 400 * 10 ** 6;

        vm.prank(investor1);
        uint256 p1 = dao.submitProposal(projectId, "Panel cleaning", amt1, payable(vendorAddr));
        vm.prank(investor1);
        uint256 p2 = dao.submitProposal(projectId, "Wiring repair", amt2, payable(vendorAddr));

        // Both proposals active simultaneously
        assertEq(uint8(dao.getProposal(p1).status), uint8(MaintenanceDAO.ProposalStatus.Active));
        assertEq(uint8(dao.getProposal(p2).status), uint8(MaintenanceDAO.ProposalStatus.Active));

        // Vote on both - each investor votes independently per proposal
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
}
