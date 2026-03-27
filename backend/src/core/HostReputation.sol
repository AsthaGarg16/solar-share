// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title HostReputation - Soulbound ERC-721 on-chain credit score
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

    /// @notice Mint soulbound token to a new host
    function mintSBT(address host) external returns (uint256 tokenId) {
        if (hostScores[host].exists) revert AlreadyHasSBT();

        tokenId = _nextTokenId++;
        _safeMint(host, tokenId);

        hostScores[host] = ReputationScore({
            score: INITIAL_SCORE,
            projectsCreated: 1,
            projectsCompleted: 0,
            projectsDefaulted: 0,
            totalSlashed: 0,
            exists: true
        });

        hostToTokenId[host] = tokenId;
        tokenIdToHost[tokenId] = host;

        emit SBTMinted(host, tokenId, INITIAL_SCORE);
    }

    /// @notice Slash host's reputation score (only SLASHER_ROLE)
    function slashScore(address host, uint256 penaltyAmount) external onlyRole(SLASHER_ROLE) {
        if (!hostScores[host].exists) revert HostHasNoSBT();

        ReputationScore storage rep = hostScores[host];
        uint256 newScore = rep.score >= penaltyAmount ? rep.score - penaltyAmount : 0;

        rep.score = newScore;
        rep.projectsDefaulted += 1;
        rep.totalSlashed += penaltyAmount;

        emit ScoreSlashed(host, penaltyAmount, newScore);
    }

    /// @notice Get reputation score for a host
    function getScore(address host) external view returns (uint256 score) {
        return hostScores[host].score;
    }

    /// @notice Increment projects completed counter
    function incrementProjectsCompleted(address host) external onlyRole(SLASHER_ROLE) {
        if (!hostScores[host].exists) revert HostHasNoSBT();
        hostScores[host].projectsCompleted += 1;
        emit ProjectCompleted(host, hostScores[host].projectsCompleted);
    }

    /// @notice Get full reputation details for a host
    function getReputationDetails(address host) external view returns (ReputationScore memory) {
        return hostScores[host];
    }

    /*//////////////////////////////////////////////////////////////
                         SOULBOUND OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev Block all transfers except minting
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (from != address(0)) revert SoulboundCannotTransfer();
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (from != address(0)) revert SoulboundCannotTransfer();
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function approve(address, uint256) public pure override {
        revert SoulboundCannotTransfer();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert SoulboundCannotTransfer();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
