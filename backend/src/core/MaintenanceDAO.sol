// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISolarProject} from "../interfaces/ISolarProject.sol";
import {IRevenueDistributor} from "../interfaces/IRevenueDistributor.sol";

/// @title MaintenanceDAO - Democratic governance for the 5% maintenance reserve
contract MaintenanceDAO {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroVendorAddress();
    error AmountExceedsReserve();
    error ProposalNotActive();
    error VotingNotEnded();
    error VotingEnded();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidProposal();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProposalSubmitted(
        uint256 indexed proposalId,
        uint256 indexed projectId,
        address indexed proposer,
        string description,
        uint256 amount,
        address vendor,
        uint256 votingDeadline
    );

    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);

    event ProposalExecuted(uint256 indexed proposalId, bool passed, uint256 yesVotes, uint256 noVotes);

    event FundsTransferred(uint256 indexed proposalId, address indexed vendor, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    enum ProposalStatus {
        Active,
        Passed,
        Rejected,
        Executed
    }

    struct Proposal {
        uint256 proposalId;
        uint256 projectId;
        address proposer;
        string description;
        uint256 amount;
        address payable vendor;
        uint256 votingDeadline;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        bool passed;
        ProposalStatus status;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;

    ISolarProject public immutable solarProject;
    IRevenueDistributor public immutable revenueDistributor;
    IERC20 public immutable usdc;

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_PERCENTAGE = 50;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solarProject, address _revenueDistributor, address _usdc) {
        solarProject = ISolarProject(_solarProject);
        revenueDistributor = IRevenueDistributor(_revenueDistributor);
        usdc = IERC20(_usdc);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Submit a repair/maintenance proposal
    function submitProposal(uint256 projectId, string memory description, uint256 amount, address payable vendor)
        external
        returns (uint256 proposalId)
    {
        if (vendor == address(0)) revert ZeroVendorAddress();
        uint256 reserve = revenueDistributor.getMaintenanceReserve(projectId);
        if (amount > reserve) revert AmountExceedsReserve();

        proposalId = ++proposalCount;
        uint256 deadline = block.timestamp + VOTING_PERIOD;

        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            projectId: projectId,
            proposer: msg.sender,
            description: description,
            amount: amount,
            vendor: vendor,
            votingDeadline: deadline,
            yesVotes: 0,
            noVotes: 0,
            executed: false,
            passed: false,
            status: ProposalStatus.Active
        });

        emit ProposalSubmitted(proposalId, projectId, msg.sender, description, amount, vendor, deadline);
    }

    /// @notice Cast vote on a proposal
    function castVote(uint256 proposalId, bool support) external {
        if (proposalId == 0 || proposalId > proposalCount) revert InvalidProposal();
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status != ProposalStatus.Active) revert ProposalNotActive();
        if (block.timestamp > proposal.votingDeadline) revert VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        uint256 votingPower = solarProject.getInvestorShares(proposal.projectId, msg.sender);
        if (votingPower == 0) revert NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            proposal.yesVotes += votingPower;
        } else {
            proposal.noVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    /// @notice Execute proposal after voting period ends
    function executeProposal(uint256 proposalId) external {
        if (proposalId == 0 || proposalId > proposalCount) revert InvalidProposal();
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status != ProposalStatus.Active) revert ProposalNotActive();
        if (block.timestamp <= proposal.votingDeadline) revert VotingNotEnded();

        uint256 totalShares = solarProject.getTotalShares(proposal.projectId);
        uint256 quorum = (totalShares * QUORUM_PERCENTAGE) / 100;
        bool passed = proposal.yesVotes > quorum;

        if (passed) {
            proposal.passed = true;
            proposal.executed = true;
            proposal.status = ProposalStatus.Executed;
            revenueDistributor.withdrawMaintenance(proposal.projectId, proposal.amount, proposal.vendor);
            emit FundsTransferred(proposalId, proposal.vendor, proposal.amount);
        } else {
            proposal.status = ProposalStatus.Rejected;
        }

        emit ProposalExecuted(proposalId, passed, proposal.yesVotes, proposal.noVotes);
    }

    /// @notice Get full proposal details
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    /// @notice Check if voter has voted on proposal
    function hasVotedOnProposal(uint256 proposalId, address voter) external view returns (bool) {
        return hasVoted[proposalId][voter];
    }

    /// @notice Get voting power (token balance) for a voter in a project
    function getVotingPower(uint256 projectId, address voter) external view returns (uint256) {
        return solarProject.getInvestorShares(projectId, voter);
    }
}
