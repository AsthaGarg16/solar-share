// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {MaintenanceDAO} from "../../src/core/MaintenanceDAO.sol";

contract MaintenanceDAOTest is BaseTest {
  // Re-declare events for expectEmit
  event ProposalSubmitted(
    uint256 indexed proposalId,
    uint256 indexed projectId,
    address indexed proposer,
    string description,
    uint256 amount,
    address vendor,
    uint256 votingDeadline
  );
  event VoteCast(
    uint256 indexed proposalId,
    address indexed voter,
    bool support,
    uint256 votingPower
  );
  event ProposalExecuted(
    uint256 indexed proposalId,
    bool passed,
    uint256 yesVotes,
    uint256 noVotes
  );
  event FundsTransferred(uint256 indexed proposalId, address indexed vendor, uint256 amount);

  uint256 public projectId;
  uint256 public constant REVENUE_AMOUNT = 10_000 * 10 ** 6; // $10,000 to generate reserve
  uint256 public constant PROPOSAL_AMOUNT = 500 * 10 ** 6; // $500 proposal

  function setUp() public override {
    super.setUp();
    projectId = _setupFullProject();
    _generateMaintenanceReserve(projectId, REVENUE_AMOUNT);
  }

  /*//////////////////////////////////////////////////////////////
                        PROPOSAL SUBMISSION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_AnyoneCanSubmitProposal() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Replace inverter",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );
    assertEq(proposalId, 1);
  }

  function test_ProposalIdIncrements() public {
    vm.prank(investor1);
    dao.submitProposal(projectId, "Proposal 1", PROPOSAL_AMOUNT / 2, payable(vendor));
    vm.prank(investor2);
    dao.submitProposal(projectId, "Proposal 2", PROPOSAL_AMOUNT / 2, payable(vendor));
    assertEq(dao.proposalCount(), 2);
  }

  function test_ProposalDetailsStoredCorrectly() public {
    uint256 deadline = block.timestamp + dao.VOTING_PERIOD();
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Replace inverter",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );

    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(p.proposalId, 1);
    assertEq(p.projectId, projectId);
    assertEq(p.proposer, investor1);
    assertEq(p.description, "Replace inverter");
    assertEq(p.amount, PROPOSAL_AMOUNT);
    assertEq(p.vendor, vendor);
    assertEq(p.votingDeadline, deadline);
    assertEq(p.yesVotes, 0);
    assertEq(p.noVotes, 0);
    assertEq(p.executed, false);
    assertEq(p.passed, false);
    assertEq(uint8(p.status), uint8(MaintenanceDAO.ProposalStatus.Active));
  }

  function test_VotingDeadlineSetTo7Days() public {
    uint256 before = block.timestamp;
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(p.votingDeadline, before + 7 days);
  }

  function test_InitialStatusIsActive() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(uint8(p.status), uint8(MaintenanceDAO.ProposalStatus.Active));
  }

  function test_RevertWhen_ZeroVendorAddress() public {
    vm.expectRevert(MaintenanceDAO.ZeroVendorAddress.selector);
    vm.prank(investor1);
    dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(address(0)));
  }

  function test_RevertWhen_AmountExceedsReserve() public {
    uint256 reserve = distributor.getMaintenanceReserve(projectId);
    vm.expectRevert(MaintenanceDAO.AmountExceedsReserve.selector);
    vm.prank(investor1);
    dao.submitProposal(projectId, "Test", reserve + 1, payable(vendor));
  }

  function test_EmitsProposalSubmitted() public {
    uint256 deadline = block.timestamp + 7 days;
    vm.expectEmit(true, true, true, true);
    emit ProposalSubmitted(
      1,
      projectId,
      investor1,
      "Replace inverter",
      PROPOSAL_AMOUNT,
      vendor,
      deadline
    );
    vm.prank(investor1);
    dao.submitProposal(projectId, "Replace inverter", PROPOSAL_AMOUNT, payable(vendor));
  }

  /*//////////////////////////////////////////////////////////////
                             VOTING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_TokenHolderCanVote() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(p.yesVotes, 500); // investor1 has 500 shares
  }

  function test_VotingPowerEqualsTokenBalance() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));

    // investor1 has 500, investor2 has 300, investor3 has 200
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, false);

    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(p.yesVotes, 500);
    assertEq(p.noVotes, 300);
  }

  function test_YesVoteIncreasesYesVotes() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    assertEq(dao.getProposal(proposalId).yesVotes, 500);
    assertEq(dao.getProposal(proposalId).noVotes, 0);
  }

  function test_NoVoteIncreasesNoVotes() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, false);
    assertEq(dao.getProposal(proposalId).noVotes, 500);
    assertEq(dao.getProposal(proposalId).yesVotes, 0);
  }

  function test_RevertWhen_VoteTwice() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.startPrank(investor1);
    dao.castVote(proposalId, true);
    vm.expectRevert(MaintenanceDAO.AlreadyVoted.selector);
    dao.castVote(proposalId, true);
    vm.stopPrank();
  }

  function test_RevertWhen_VoteWithZeroTokens() public {
    address nonHolder = makeAddr("nonHolder");
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.expectRevert(MaintenanceDAO.NoVotingPower.selector);
    vm.prank(nonHolder);
    dao.castVote(proposalId, true);
  }

  function test_RevertWhen_VoteAfterDeadline() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.warp(block.timestamp + 7 days + 1);
    vm.expectRevert(MaintenanceDAO.VotingEnded.selector);
    vm.prank(investor1);
    dao.castVote(proposalId, true);
  }

  function test_EmitsVoteCast() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.expectEmit(true, true, false, true);
    emit VoteCast(proposalId, investor1, true, 500);
    vm.prank(investor1);
    dao.castVote(proposalId, true);
  }

  function test_HasVotedOnProposal() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    assertFalse(dao.hasVotedOnProposal(proposalId, investor1));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    assertTrue(dao.hasVotedOnProposal(proposalId, investor1));
  }

  /*//////////////////////////////////////////////////////////////
                        VOTING POWER TESTS
    //////////////////////////////////////////////////////////////*/

  function test_Investor1Has500Votes() public view {
    assertEq(dao.getVotingPower(projectId, investor1), 500);
  }

  function test_Investor2Has300Votes() public view {
    assertEq(dao.getVotingPower(projectId, investor2), 300);
  }

  function test_NonHolderHas0Votes() public {
    address nobody = makeAddr("nobody");
    assertEq(dao.getVotingPower(projectId, nobody), 0);
  }

  /*//////////////////////////////////////////////////////////////
                     EXECUTION TESTS (PASSED)
    //////////////////////////////////////////////////////////////*/

  function test_RevertWhen_ExecuteBeforeDeadline() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.expectRevert(MaintenanceDAO.VotingNotEnded.selector);
    dao.executeProposal(proposalId);
  }

  function test_ProposalPassesWithMajority() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    // investor1 (500) + investor2 (300) = 800 YES > 50% of 1000 = 500
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);
    vm.prank(investor3);
    dao.castVote(proposalId, false);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertEq(uint8(p.status), uint8(MaintenanceDAO.ProposalStatus.Executed));
    assertTrue(p.passed);
    assertTrue(p.executed);
  }

  function test_FundsTransferredToVendor() public {
    uint256 vendorBalanceBefore = usdc.balanceOf(vendor);
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(usdc.balanceOf(vendor) - vendorBalanceBefore, PROPOSAL_AMOUNT);
  }

  function test_MaintenanceReserveDecreases() public {
    uint256 reserveBefore = distributor.getMaintenanceReserve(projectId);
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(distributor.getMaintenanceReserve(projectId), reserveBefore - PROPOSAL_AMOUNT);
  }

  function test_StatusChangesToExecuted() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Executed)
    );
  }

  function test_EmitsProposalExecuted() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    vm.expectEmit(true, false, false, true);
    emit ProposalExecuted(proposalId, true, 800, 0);
    dao.executeProposal(proposalId);
  }

  function test_EmitsFundsTransferred() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    vm.expectEmit(true, true, false, true);
    emit FundsTransferred(proposalId, vendor, PROPOSAL_AMOUNT);
    dao.executeProposal(proposalId);
  }

  function test_RevertWhen_ExecuteTwice() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    vm.expectRevert(MaintenanceDAO.ProposalNotActive.selector);
    dao.executeProposal(proposalId);
  }

  /*//////////////////////////////////////////////////////////////
                     EXECUTION TESTS (REJECTED)
    //////////////////////////////////////////////////////////////*/

  function test_ProposalRejectedWhenInsufficientYesVotes() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    // investor1 (500) = exactly 50% - NOT more than 50%, so REJECTED
    vm.prank(investor1);
    dao.castVote(proposalId, false);
    vm.prank(investor2);
    dao.castVote(proposalId, true); // 300 YES
    vm.prank(investor3);
    dao.castVote(proposalId, true); // 200 YES -> total 500 YES, not > 500, REJECTED

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Rejected)
    );
  }

  function test_NoFundsTransferredWhenRejected() public {
    uint256 vendorBalanceBefore = usdc.balanceOf(vendor);
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, false); // 500 NO

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(usdc.balanceOf(vendor), vendorBalanceBefore);
  }

  function test_ReserveUnchangedWhenRejected() public {
    uint256 reserveBefore = distributor.getMaintenanceReserve(projectId);
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, false);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);

    assertEq(distributor.getMaintenanceReserve(projectId), reserveBefore);
  }

  /*//////////////////////////////////////////////////////////////
                          QUORUM TESTS
    //////////////////////////////////////////////////////////////*/

  function test_Exactly50PercentYesIsRejected() public {
    // 500 YES out of 1000 total = exactly 50%, NOT > 50%, so rejected
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true); // 500 YES

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Rejected)
    );
  }

  function test_51PercentYesIsPassed() public {
    // investor1 (500) + investor2 (300) = 800 > 500 quorum
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true); // 500
    vm.prank(investor2);
    dao.castVote(proposalId, true); // 300 -> total 800 > 500

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Executed)
    );
  }

  function test_100PercentYesIsPassed() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);
    vm.prank(investor3);
    dao.castVote(proposalId, true);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Executed)
    );
  }

  function test_NoVotesCastIsRejected() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Rejected)
    );
  }

  function test_OnlyNoVotesIsRejected() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(projectId, "Test", PROPOSAL_AMOUNT, payable(vendor));
    vm.prank(investor1);
    dao.castVote(proposalId, false);
    vm.prank(investor2);
    dao.castVote(proposalId, false);
    vm.prank(investor3);
    dao.castVote(proposalId, false);

    vm.warp(block.timestamp + 7 days + 1);
    dao.executeProposal(proposalId);
    assertEq(
      uint8(dao.getProposal(proposalId).status),
      uint8(MaintenanceDAO.ProposalStatus.Rejected)
    );
  }

  /*//////////////////////////////////////////////////////////////
                          EDGE CASES
    //////////////////////////////////////////////////////////////*/

  function test_MultipleProposalsActiveSimultaneously() public {
    uint256 reserve = distributor.getMaintenanceReserve(projectId);
    uint256 amt1 = reserve / 4;
    uint256 amt2 = reserve / 4;

    vm.prank(investor1);
    uint256 p1 = dao.submitProposal(projectId, "Panel cleaning", amt1, payable(vendor));
    vm.prank(investor2);
    uint256 p2 = dao.submitProposal(projectId, "Wiring repair", amt2, payable(vendor));

    assertEq(uint8(dao.getProposal(p1).status), uint8(MaintenanceDAO.ProposalStatus.Active));
    assertEq(uint8(dao.getProposal(p2).status), uint8(MaintenanceDAO.ProposalStatus.Active));
  }

  function test_ExecuteMultipleProposalsSequentially() public {
    uint256 amt1 = 200 * 10 ** 6;
    uint256 amt2 = 200 * 10 ** 6;

    vm.prank(investor1);
    uint256 p1 = dao.submitProposal(projectId, "Proposal 1", amt1, payable(vendor));
    vm.prank(investor2);
    uint256 p2 = dao.submitProposal(projectId, "Proposal 2", amt2, payable(vendor));

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
    assertEq(usdc.balanceOf(vendor), amt1 + amt2);
  }

  /*//////////////////////////////////////////////////////////////
                        WEATHER ORACLE TESTS
    //////////////////////////////////////////////////////////////*/

  function test_RequestWeatherVerification() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Storm Damage",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );

    // This should not revert and correctly calls the oracle
    dao.requestWeatherVerification(proposalId, "90210");
  }

  function test_ParametricBypass_ExecutionBeforeDeadline() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Storm Damage",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );

    // 1. Simulate a Disaster via the Mock Oracle
    // (Threshold is 15, so we set it to 20)
    weatherOracle.setRainyDays(projectId, 20);

    // 2. Try to execute immediately (without waiting 7 days and without votes!)
    // In the original DAO, this would revert with VotingNotEnded().
    // In the Oracle DAO, this should pass.
    dao.executeProposal(proposalId);

    // 3. Verify success
    MaintenanceDAO.Proposal memory p = dao.getProposal(proposalId);
    assertTrue(p.executed, "Should be executed via weather bypass");
    assertEq(uint8(p.status), uint8(MaintenanceDAO.ProposalStatus.Executed));
    assertEq(usdc.balanceOf(vendor), PROPOSAL_AMOUNT, "Vendor should be paid");
  }

  function test_NoBypass_WhenWeatherIsGood() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Normal Wear",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );

    // 1. Set weather below threshold (e.g., 5 rainy days)
    weatherOracle.setRainyDays(projectId, 5);

    // 2. Try to execute immediately
    // This SHOULD still revert because weather didn't trigger the shortcut
    vm.expectRevert(MaintenanceDAO.VotingNotEnded.selector);
    dao.executeProposal(proposalId);
  }

  function test_NormalPath_StillWorksAfterDeadline() public {
    vm.prank(investor1);
    uint256 proposalId = dao.submitProposal(
      projectId,
      "Normal Wear",
      PROPOSAL_AMOUNT,
      payable(vendor)
    );

    // 1. Vote normally (No weather trigger)
    vm.prank(investor1);
    dao.castVote(proposalId, true);
    vm.prank(investor2);
    dao.castVote(proposalId, true);

    // 2. Wait 7 days
    vm.warp(block.timestamp + 7 days + 1);

    // 3. Execute should work via standard Path B
    dao.executeProposal(proposalId);

    assertTrue(dao.getProposal(proposalId).executed);
  }
}
