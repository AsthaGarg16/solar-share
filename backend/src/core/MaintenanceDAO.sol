// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISolarProject } from "../interfaces/ISolarProject.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";
import { IWeatherOracle } from "../interfaces/IWeatherOracle.sol";

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
    error WeatherDataNotAvailable(); // New error for oracle checks

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

    event VoteCast(
        uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower
    );

    event ProposalExecuted(
        uint256 indexed proposalId, bool passed, uint256 yesVotes, uint256 noVotes
    );

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

    ISolarProject public immutable SOLAR_PROJECT;
    IRevenueDistributor public immutable REVENUE_DISTRIBUTOR;
    IERC20 public immutable USDC;
    IWeatherOracle public immutable WEATHER_ORACLE;

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_PERCENTAGE = 50;

    // Oracle Additions
    // If the Oracle returns 15 or more rainy days, the contract considers it an "Act of God," which triggers an automatic payout bypass.
    uint256 public constant RAINY_DAY_THRESHOLD = 15;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solarProject, address _revenueDistributor, address _usdc, address _weatherOracle) {
        SOLAR_PROJECT = ISolarProject(_solarProject);
        REVENUE_DISTRIBUTOR = IRevenueDistributor(_revenueDistributor);
        USDC = IERC20(_usdc);
        WEATHER_ORACLE = IWeatherOracle(_weatherOracle);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Submit a repair/maintenance proposal
    function submitProposal(
        uint256 projectId,
        string memory description,
        uint256 amount,
        address payable vendor
    ) external returns (uint256 proposalId) {
        if (vendor == address(0)) revert ZeroVendorAddress();
        uint256 reserve = REVENUE_DISTRIBUTOR.getMaintenanceReserve(projectId);
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

        emit ProposalSubmitted(
            proposalId, projectId, msg.sender, description, amount, vendor, deadline
        );
    }

    /// @notice Cast vote on a proposal
    function castVote(uint256 proposalId, bool support) external {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert InvalidProposal();
        }
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status != ProposalStatus.Active) {
            revert ProposalNotActive();
        }
        if (block.timestamp > proposal.votingDeadline) revert VotingEnded();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        uint256 votingPower = SOLAR_PROJECT.getInvestorShares(proposal.projectId, msg.sender);
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
        if (proposalId == 0 || proposalId > proposalCount) {
            revert InvalidProposal();
        }
        
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status != ProposalStatus.Active) {
            revert ProposalNotActive();
        }

        // Check Oracle Data for Parametric Trigger
        uint256 rainyDays = WEATHER_ORACLE.getRainyDays(proposal.projectId);
        bool isDisasterTrigger = (rainyDays >= RAINY_DAY_THRESHOLD);
        bool isTimeExpired = (block.timestamp > proposal.votingDeadline);

        // Path A: The Parametric "Fast-Track" = "isDisasterTrigger"
        // If the data says it rained more than 15 days, we don't care about the 7-day voting period.
        // The host gets paid immediately. This is "Parametric Insurance"—data is the authority.
        // Path B: The Standard Democracy Path = "isTimeExpired"
        // If it didn't rain (e.g., a panel just broke due to age), we fall back to the standard rules.
        // The contract waits 7 days (isTimeExpired) and checks if the investors voted "Yes" (passed).
        if (isDisasterTrigger) {
            _finalizeExecution(proposalId, true); // Act of God: Execute immediately using the helper, bypasses voting/quorum
        } else if (isTimeExpired) {
            uint256 totalShares = SOLAR_PROJECT.getTotalShares(proposal.projectId); // Standard Path: Check Voting Results
            uint256 quorum = (totalShares * QUORUM_PERCENTAGE) / 100;
            bool passed = proposal.yesVotes > quorum;

            if (passed) {
                _finalizeExecution(proposalId, true);
            } else {
                proposal.status = ProposalStatus.Rejected;
                emit ProposalExecuted(proposalId, false, proposal.yesVotes, proposal.noVotes);
            } 
        } else {
            revert VotingNotEnded(); // Neither a disaster nor is the voting over yet
        } 
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
        return SOLAR_PROJECT.getInvestorShares(projectId, voter);
    }

    // This is the start of the Chainlink Functions flow. It sends the project’s Zip Code to the Oracle contract, 
    // which then signals the off-chain nodes to run your weather.js script.
    /// @notice NEW: Triggers a Chainlink Functions request for weather data
    function requestWeatherVerification(uint256 proposalId, string calldata zipCode) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.status != ProposalStatus.Active) revert ProposalNotActive();
        WEATHER_ORACLE.requestWeatherCheck(proposal.projectId, zipCode);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    // The Paymaster (Internal Helper)

    /// @dev Internal logic to handle the payout and state updates
    function _finalizeExecution(uint256 proposalId, bool passed) internal {
        Proposal storage proposal = proposals[proposalId];
        proposal.passed = passed;
        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;

        // This is the most important line in the whole DAO. 
        // It calls your RevenueDistributor contract and tells it to release the 5% reserve funds to the repair vendor's wallet.
        REVENUE_DISTRIBUTOR.withdrawMaintenance(
            proposal.projectId, proposal.amount, proposal.vendor
        );

        emit FundsTransferred(proposalId, proposal.vendor, proposal.amount);
        // This locks the proposal forever so the vendor can't be paid twice for the same job.
        emit ProposalExecuted(proposalId, passed, proposal.yesVotes, proposal.noVotes);
    }
}
