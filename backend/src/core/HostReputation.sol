// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title HostReputation
 * @notice Soulbound ERC-721 acting as an on-chain credit score for Solar Project Hosts.
 * Non-transferable tokens that track project performance and defaults.
 */
contract HostReputation is ERC721, AccessControl {
  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error AlreadyHasSBT();
  error HostHasNoSBT();
  error SoulboundCannotTransfer();

  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event SBTMinted(address indexed host, uint256 indexed tokenId, uint256 initialScore);
  event ScoreSlashed(address indexed host, uint256 penaltyAmount, uint256 newScore);
  event ProjectCompleted(address indexed host, uint256 totalCompleted);

  /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  struct ReputationScore {
    uint256 score;
    uint256 projectsCreated;
    uint256 projectsCompleted;
    uint256 projectsDefaulted;
    uint256 totalSlashed;
    bool exists;
  }

  mapping(address => ReputationScore) public hostScores;
  mapping(address => uint256) public hostToTokenId;
  mapping(uint256 => address) public tokenIdToHost;

  uint256 private _nextTokenId = 1;

  uint256 public constant INITIAL_SCORE = 1000;
  bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor() ERC721("Solar Host Reputation", "SHR") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Mint soulbound token to a new host.
   * @dev Only one SBT per address allowed.
   */
  function mintSBT(address host) external returns (uint256 tokenId) {
    if (hostScores[host].exists) revert AlreadyHasSBT();

    tokenId = _nextTokenId++;

    hostScores[host] = ReputationScore({
      score: INITIAL_SCORE,
      projectsCreated: 0,
      projectsCompleted: 0,
      projectsDefaulted: 0,
      totalSlashed: 0,
      exists: true
    });

    hostToTokenId[host] = tokenId;
    tokenIdToHost[tokenId] = host;

    _safeMint(host, tokenId);

    emit SBTMinted(host, tokenId, INITIAL_SCORE);
  }

  /**
   * @notice Slash host's reputation score.
   * @dev Only addresses with SLASHER_ROLE (like the LoanManager) can call this.
   */
  function slashScore(address host, uint256 penaltyAmount) external onlyRole(SLASHER_ROLE) {
    if (!hostScores[host].exists) revert HostHasNoSBT();

    ReputationScore storage rep = hostScores[host];
    uint256 currentScore = rep.score;
    uint256 newScore = currentScore >= penaltyAmount ? currentScore - penaltyAmount : 0;

    rep.score = newScore;
    rep.projectsDefaulted += 1;
    rep.totalSlashed += penaltyAmount;

    emit ScoreSlashed(host, penaltyAmount, newScore);
  }

  function incrementProjectsCompleted(address host) external onlyRole(SLASHER_ROLE) {
    if (!hostScores[host].exists) revert HostHasNoSBT();
    hostScores[host].projectsCompleted += 1;
    emit ProjectCompleted(host, hostScores[host].projectsCompleted);
  }

  function incrementProjectsCreated(address host) external onlyRole(SLASHER_ROLE) {
    if (!hostScores[host].exists) revert HostHasNoSBT();
    hostScores[host].projectsCreated += 1;
    // 可以加一个 emit Event 方便前端监听
  }

  /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function getScore(address host) external view returns (uint256) {
    return hostScores[host].score;
  }

  function getReputationDetails(address host) external view returns (ReputationScore memory) {
    return hostScores[host];
  }

  function hasSBT(address host) external view returns (bool) {
    return hostScores[host].exists;
  }

  /*//////////////////////////////////////////////////////////////
                         SOULBOUND OVERRIDES
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev Disables standard ERC721 transfers to make the token Soulbound.
   */
  // function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
  //     address from = _ownerOf(tokenId);
  //     // Allow minting (from == address(0)), but revert on any transfer (from != address(0))
  //     if (from != address(0) && to != address(0)) {
  //         revert SoulboundCannotTransfer();
  //     }
  //     return super._update(to, tokenId, auth);
  // }
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 firstTokenId, // V4.9 的参数名
    uint256 batchSize // V4.9 的参数名
  ) internal override(ERC721) {
    // 确保 override 了父类

    // 逻辑：允许铸造 (from == 0)，允许销毁 (to == 0)，但禁止账户间转账
    if (from != address(0) && to != address(0)) {
      revert SoulboundCannotTransfer();
    }

    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
  }

  // Overriding transfer functions for extra safety/clarity
  function transferFrom(address, address, uint256) public pure override {
    revert SoulboundCannotTransfer();
  }

  function approve(address, uint256) public pure override {
    revert SoulboundCannotTransfer();
  }

  function setApprovalForAll(address, bool) public pure override {
    revert SoulboundCannotTransfer();
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
