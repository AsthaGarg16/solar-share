// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";
import {ISolarProject} from "../interfaces/ISolarProject.sol";

/// @title SolarProject - Capital formation, ERC-1155 fractional ownership, buyouts
contract SolarProject is ERC1155, ISolarProject {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidTargetAmount();
    error InvalidTermMonths();
    error InvalidTotalShares();
    error NotInFundingStatus();
    error NotInActiveStatus();
    error ExceedsAvailableShares();
    error ZeroShares();
    error ProjectAlreadyFunded();
    error OnlyHostOrLoanManager();
    error OnlyLoanManager();
    error LoanManagerNotSet();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProjectCreated(
        uint256 indexed projectId, address indexed host, uint256 targetAmount, uint256 termMonths
    );
    event ProjectFunded(
        uint256 indexed projectId, address indexed investor, uint256 numShares, uint256 amount
    );
    event SharesMinted(uint256 indexed projectId, address indexed investor, uint256 numShares);
    event BuyoutTriggered(
        uint256 indexed projectId,
        uint256 offerAmount,
        uint256 hostShare,
        uint256 investorShare
    );
    event ProjectStatusChanged(uint256 indexed projectId, ProjectStatus newStatus);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    IERC20 public immutable usdc;
    ILoanManager public loanManager;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _usdc) ERC1155("") {
        usdc = IERC20(_usdc);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the LoanManager address (one-time setup)
    function setLoanManager(address _loanManager) external {
        require(address(loanManager) == address(0), "Already set");
        loanManager = ILoanManager(_loanManager);
    }

    /// @notice Host creates a new solar project
    function initializeProject(uint256 targetAmount, uint256 termMonths, uint256 totalShares)
        external
        returns (uint256 projectId)
    {
        if (targetAmount == 0) revert InvalidTargetAmount();
        if (termMonths == 0) revert InvalidTermMonths();
        if (totalShares == 0) revert InvalidTotalShares();

        projectId = ++projectCount;
        uint256 pricePerShare = targetAmount / totalShares;

        projects[projectId] = Project({
            projectId: projectId,
            host: msg.sender,
            targetAmount: targetAmount,
            amountRaised: 0,
            totalShares: totalShares,
            sharesSold: 0,
            pricePerShare: pricePerShare,
            termMonths: termMonths,
            startDate: block.timestamp,
            isFunded: false,
            isBoughtOut: false,
            status: ProjectStatus.Funding
        });

        emit ProjectCreated(projectId, msg.sender, targetAmount, termMonths);
    }

    /// @notice Investor funds a project by purchasing shares
    function fundProject(uint256 projectId, uint256 numShares) external {
        Project storage project = projects[projectId];

        if (project.status != ProjectStatus.Funding) revert NotInFundingStatus();
        if (numShares == 0) revert ZeroShares();
        if (project.sharesSold + numShares > project.totalShares) revert ExceedsAvailableShares();

        uint256 amount = numShares * project.pricePerShare;

        // CEI: Effects before interactions
        project.amountRaised += amount;
        project.sharesSold += numShares;

        // Mint ERC-1155 shares
        _mint(msg.sender, projectId, numShares, "");

        // Transfer USDC from investor to contract
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit ProjectFunded(projectId, msg.sender, numShares, amount);
        emit SharesMinted(projectId, msg.sender, numShares);

        // Check if fully funded
        if (project.amountRaised >= project.targetAmount) {
            project.isFunded = true;
            project.status = ProjectStatus.Active;
            emit ProjectStatusChanged(projectId, ProjectStatus.Active);
        }
    }

    /// @notice Triggers buyout of investor shares
    function triggerBuyout(uint256 projectId, uint256 offerAmount) external {
        Project storage project = projects[projectId];

        if (project.status != ProjectStatus.Active && project.status != ProjectStatus.Defaulted) {
            revert NotInActiveStatus();
        }
        if (msg.sender != project.host && msg.sender != address(loanManager)) {
            revert OnlyHostOrLoanManager();
        }

        // Get equity split from LoanManager
        (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);

        uint256 hostAmount = (offerAmount * hostPercent) / 100;
        uint256 investorAmount = (offerAmount * investorPercent) / 100;

        // Pull buyout funds from caller
        usdc.safeTransferFrom(msg.sender, address(this), offerAmount);

        // Send host portion to host
        if (hostAmount > 0) {
            usdc.safeTransfer(project.host, hostAmount);
        }

        // Distribute investor portion pro-rata (tracked by ERC-1155 balances)
        // Funds remain in contract; investors can now claim
        // We store the investor amount as a separate pool via a simple mapping
        _distributeBuyoutToInvestors(projectId, investorAmount);

        project.isBoughtOut = true;
        project.status = ProjectStatus.BoughtOut;

        emit BuyoutTriggered(projectId, offerAmount, hostAmount, investorAmount);
        emit ProjectStatusChanged(projectId, ProjectStatus.BoughtOut);
    }

    /// @notice Mark project as defaulted (called by LoanManager)
    function setProjectDefaulted(uint256 projectId) external {
        if (msg.sender != address(loanManager)) revert OnlyLoanManager();
        projects[projectId].status = ProjectStatus.Defaulted;
        emit ProjectStatusChanged(projectId, ProjectStatus.Defaulted);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getProjectDetails(uint256 projectId) external view returns (Project memory) {
        return projects[projectId];
    }

    function getInvestorShares(uint256 projectId, address investor) external view returns (uint256) {
        return balanceOf(investor, projectId);
    }

    function getTotalShares(uint256 projectId) external view returns (uint256) {
        return projects[projectId].totalShares;
    }

    function getProjectHost(uint256 projectId) external view returns (address) {
        return projects[projectId].host;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Distribute buyout funds to all shareholders proportionally via per-share accounting
    /// We use a simple approach: record the per-share payout and let investors claim
    mapping(uint256 => uint256) public buyoutPerShare; // projectId => USDC per share (scaled 1e18)
    mapping(uint256 => mapping(address => uint256)) public buyoutClaimed;

    function _distributeBuyoutToInvestors(uint256 projectId, uint256 investorAmount) internal {
        Project storage project = projects[projectId];
        if (project.totalShares > 0 && investorAmount > 0) {
            buyoutPerShare[projectId] += (investorAmount * 1e18) / project.totalShares;
        }
    }

    /// @notice Investor claims their buyout proceeds after buyout triggered
    function claimBuyout(uint256 projectId) external returns (uint256 claimable) {
        uint256 shares = balanceOf(msg.sender, projectId);
        uint256 totalOwed = (shares * buyoutPerShare[projectId]) / 1e18;
        uint256 claimed = buyoutClaimed[projectId][msg.sender];
        claimable = totalOwed > claimed ? totalOwed - claimed : 0;

        require(claimable > 0, "Nothing to claim");

        buyoutClaimed[projectId][msg.sender] = totalOwed;

        // Burn investor tokens
        _burn(msg.sender, projectId, shares);

        usdc.safeTransfer(msg.sender, claimable);
    }
}
