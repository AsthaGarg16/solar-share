// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "../Base.t.sol";
import {HostReputation} from "../../src/core/HostReputation.sol";

contract HostReputationTest is BaseTest {
  // Re-declare events for expectEmit
  event SBTMinted(address indexed host, uint256 indexed tokenId, uint256 initialScore);
  event ScoreSlashed(address indexed host, uint256 penaltyAmount, uint256 newScore);
  event ProjectCompleted(address indexed host, uint256 totalCompleted);

  address public slasher = makeAddr("slasher");

  function setUp() public override {
    super.setUp();
    // Grant slasher role to test slasher address
    // Note: must get the role bytes32 BEFORE vm.prank (view call consumes prank)
    bytes32 slasherRole = reputation.SLASHER_ROLE();
    vm.prank(owner);
    reputation.grantRole(slasherRole, slasher);
  }

  /*//////////////////////////////////////////////////////////////
                            MINTING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_MintSBTToHost() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);
    assertEq(reputation.ownerOf(tokenId), host);
  }

  function test_TokenIdIncrements() public {
    vm.prank(host);
    uint256 id1 = reputation.mintSbt(host);

    address host2 = makeAddr("host2");
    vm.prank(host2);
    uint256 id2 = reputation.mintSbt(host2);

    assertEq(id1, 1);
    assertEq(id2, 2);
  }

  function test_InitialScoreIs1000() public {
    vm.prank(host);
    reputation.mintSbt(host);
    assertEq(reputation.getScore(host), 1000);
  }

  function test_ReputationScoreCreatedCorrectly() public {
    vm.prank(host);
    reputation.mintSbt(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.score, 1000);
    assertEq(rep.projectsCreated, 0);
    assertEq(rep.projectsCompleted, 0);
    assertEq(rep.projectsDefaulted, 0);
    assertEq(rep.totalSlashed, 0);
    assertTrue(rep.exists);
  }

  function test_RevertWhen_MintTwiceToSameHost() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(host);
    vm.expectRevert(HostReputation.AlreadyHasSBT.selector);
    reputation.mintSbt(host);
  }

  function test_MintSBT_EmitsSBTMinted() public {
    vm.expectEmit(true, true, false, true);
    emit SBTMinted(host, 1, 1000);
    vm.prank(host);
    reputation.mintSbt(host);
  }

  function test_HostToTokenIdMapping() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);
    assertEq(reputation.hostToTokenId(host), tokenId);
  }

  function test_TokenIdToHostMapping() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);
    assertEq(reputation.tokenIdToHost(tokenId), host);
  }

  /*//////////////////////////////////////////////////////////////
                          SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/

  function test_RevertWhen_TransferToken() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);

    vm.prank(host);
    vm.expectRevert(HostReputation.SoulboundCannotTransfer.selector);
    reputation.transferFrom(host, investor1, tokenId);
  }

  function test_RevertWhen_SafeTransferToken() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);

    vm.prank(host);
    vm.expectRevert(HostReputation.SoulboundCannotTransfer.selector);
    reputation.safeTransferFrom(host, investor1, tokenId, "");
  }

  function test_RevertWhen_ApproveToken() public {
    vm.prank(host);
    uint256 tokenId = reputation.mintSbt(host);

    vm.prank(host);
    vm.expectRevert(HostReputation.SoulboundCannotTransfer.selector);
    reputation.approve(investor1, tokenId);
  }

  function test_RevertWhen_SetApprovalForAll() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(host);
    vm.expectRevert(HostReputation.SoulboundCannotTransfer.selector);
    reputation.setApprovalForAll(investor1, true);
  }

  /*//////////////////////////////////////////////////////////////
                           SLASHING TESTS
    //////////////////////////////////////////////////////////////*/

  function test_SlasherRoleCanSlash() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200);
    assertEq(reputation.getScore(host), 800);
  }

  function test_Slash200From1000Equals800() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200);
    assertEq(reputation.getScore(host), 800);
  }

  function test_Slash500From800Equals300() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200);

    vm.prank(slasher);
    reputation.slashScore(host, 500);
    assertEq(reputation.getScore(host), 300);
  }

  function test_SlashFloorAtZero() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200); // 800

    vm.prank(slasher);
    reputation.slashScore(host, 500); // 300

    vm.prank(slasher);
    reputation.slashScore(host, 400); // Should floor at 0
    assertEq(reputation.getScore(host), 0);
  }

  function test_CannotSlashBelowZero() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 10000); // Way more than score
    assertEq(reputation.getScore(host), 0); // Floors at 0
  }

  function test_ProjectsDefaultedIncrements() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.projectsDefaulted, 1);
  }

  function test_TotalSlashedAccumulates() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.slashScore(host, 200);

    vm.prank(slasher);
    reputation.slashScore(host, 100);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.totalSlashed, 300);
  }

  function test_RevertWhen_NonSlasherSlashes() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(investor1);
    vm.expectRevert();
    reputation.slashScore(host, 200);
  }

  function test_SlashScore_EmitsScoreSlashed() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    vm.expectEmit(true, false, false, true);
    emit ScoreSlashed(host, 200, 800);
    reputation.slashScore(host, 200);
  }

  function test_RevertWhen_SlashHostWithNoSBT() public {
    vm.prank(slasher);
    vm.expectRevert(HostReputation.HostHasNoSBT.selector);
    reputation.slashScore(host, 200);
  }

  /*//////////////////////////////////////////////////////////////
                          COMPLETION TESTS
    //////////////////////////////////////////////////////////////*/

  function test_IncrementProjectsCompleted() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.incrementProjectsCompleted(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.projectsCompleted, 1);
  }

  function test_ProjectsCompletedCounterIncreases() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.incrementProjectsCompleted(host);
    vm.prank(slasher);
    reputation.incrementProjectsCompleted(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.projectsCompleted, 2);
  }

  function test_IncrementCompleted_EmitsEvent() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    vm.expectEmit(true, false, false, true);
    emit ProjectCompleted(host, 1);
    reputation.incrementProjectsCompleted(host);
  }

  /*//////////////////////////////////////////////////////////////
                             VIEW TESTS
    //////////////////////////////////////////////////////////////*/

  function test_GetScoreReturnsCorrectValue() public {
    vm.prank(host);
    reputation.mintSbt(host);
    assertEq(reputation.getScore(host), 1000);
  }

  function test_GetReputationDetailsReturnsFullStruct() public {
    vm.prank(host);
    reputation.mintSbt(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertTrue(rep.exists);
    assertEq(rep.score, 1000);
    assertEq(rep.projectsCreated, 0);
  }

  // !hostScores[host].exists branch in incrementProjectsCompleted
  function test_RevertWhen_IncrementCompletedForHostWithNoSBT() public {
    address nonHost = makeAddr("nonHost");
    vm.prank(slasher);
    vm.expectRevert(HostReputation.HostHasNoSBT.selector);
    reputation.incrementProjectsCompleted(nonHost);
  }

  // !hostScores[host].exists branch in incrementProjectsCreated
  function test_RevertWhen_IncrementCreatedForHostWithNoSBT() public {
    address nonHost = makeAddr("nonHost");
    vm.prank(slasher);
    vm.expectRevert(HostReputation.HostHasNoSBT.selector);
    reputation.incrementProjectsCreated(nonHost);
  }

  // incrementProjectsCreated success path
  function test_IncrementProjectsCreated() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.incrementProjectsCreated(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.projectsCreated, 1);
  }

  // incrementProjectsCreated counter accumulates
  function test_IncrementProjectsCreated_Accumulates() public {
    vm.prank(host);
    reputation.mintSbt(host);

    vm.prank(slasher);
    reputation.incrementProjectsCreated(host);
    vm.prank(slasher);
    reputation.incrementProjectsCreated(host);

    HostReputation.ReputationScore memory rep = reputation.getReputationDetails(host);
    assertEq(rep.projectsCreated, 2);
  }
}
