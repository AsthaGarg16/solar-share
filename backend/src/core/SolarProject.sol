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
  error FundsAlreadyWithdrawn();
  error ExceedsAvailableShares();
  error ZeroShares();
  error ProjectAlreadyFunded();
  error OnlyHost();
  error OnlyHostOrLoanManager();
  error OnlyLoanManager();
  error LoanManagerNotSet();
  error ProjectNotFullyFunded();

  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event ProjectCreated(
    uint256 indexed projectId,
    address indexed host,
    uint256 targetAmount,
    uint256 termMonths
  );
  event ProjectFunded(
    uint256 indexed projectId,
    address indexed investor,
    uint256 numShares,
    uint256 amount
  );
  event SharesMinted(uint256 indexed projectId, address indexed investor, uint256 numShares);
  event BuyoutTriggered(
    uint256 indexed projectId,
    uint256 offerAmount,
    uint256 hostShare,
    uint256 investorShare
  );
  event ProjectStatusChanged(uint256 indexed projectId, ProjectStatus newStatus);
  event ProjectStatusUpdated(uint256 indexed projectId, ProjectStatus newStatus);
  event FundsWithdrawn(uint256 indexed projectId, address indexed host, uint256 amount);

  /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  mapping(uint256 => Project) public projects;
  uint256 public projectCount;

  IERC20 public immutable USDC;
  ILoanManager public loanManager;

  constructor(address _usdc) ERC1155("") {
    USDC = IERC20(_usdc);
  }

  /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice This function moves the USDC to the Host and triggers the LoanManager
  function withdrawFunds(uint256 projectId) external {
    Project storage project = projects[projectId];
    if (msg.sender != project.host) revert OnlyHostOrLoanManager();
    if (!project.isFunded) revert ProjectNotFullyFunded();
    if (address(loanManager) == address(0)) revert LoanManagerNotSet();

    uint256 amount = project.amountRaised;

    project.status = ProjectStatus.Active;

    // Interaction: Trigger LoanManager to start the repayment schedule
    uint256 monthlyPayment = project.targetAmount / project.termMonths;
    loanManager.initializeLoan(projectId, monthlyPayment, project.termMonths);

    // Interaction: Send capital to Host for installation
    USDC.safeTransfer(project.host, amount);

    emit FundsWithdrawn(projectId, project.host, amount);
    emit ProjectStatusChanged(projectId, ProjectStatus.Active);
  }

  function completeProject(uint256 projectId) external {
    require(msg.sender == address(loanManager), "Unauthorized");
    projects[projectId].status = ProjectStatus.BoughtOut;
    emit ProjectStatusUpdated(projectId, ProjectStatus.BoughtOut);
  }

  function setLoanManager(address _loanManager) external {
    require(address(loanManager) == address(0), "Already set");
    loanManager = ILoanManager(_loanManager);
  }

  function initializeProject(
    string memory name,
    uint256 targetAmount,
    uint256 termMonths,
    uint256 totalShares
  ) external returns (uint256 projectId) {
    if (targetAmount == 0) revert InvalidTargetAmount();
    if (termMonths == 0) revert InvalidTermMonths();
    if (totalShares == 0) revert InvalidTotalShares();

    projectId = ++projectCount;
    uint256 pricePerShare = targetAmount / totalShares;

    projects[projectId] = Project({
      projectId: projectId,
      host: msg.sender,
      name: name,
      targetAmount: targetAmount,
      amountRaised: 0,
      totalShares: totalShares,
      sharesSold: 0,
      pricePerShare: pricePerShare,
      termMonths: termMonths,
      startDate: block.timestamp,
      isFunded: false,
      isBoughtOut: false,
      fundsWithdrawn: false,
      status: ProjectStatus.Funding
    });

    emit ProjectCreated(projectId, msg.sender, targetAmount, termMonths);
  }

  function fundProject(uint256 projectId, uint256 numShares) external {
    Project storage project = projects[projectId];
    if (project.status != ProjectStatus.Funding) revert NotInFundingStatus();
    if (numShares == 0) revert ZeroShares();
    if (project.sharesSold + numShares > project.totalShares) revert ExceedsAvailableShares();

    uint256 amount = numShares * project.pricePerShare;

    project.amountRaised += amount;
    project.sharesSold += numShares;

    _mint(msg.sender, projectId, numShares, "");
    USDC.safeTransferFrom(msg.sender, address(this), amount);

    emit ProjectFunded(projectId, msg.sender, numShares, amount);

    if (project.sharesSold >= project.totalShares) {
      project.isFunded = true;
      // Note: Status remains Funding until withdrawFunds is called
    }
  }

  function triggerBuyout(uint256 projectId, uint256 offerAmount) external {
    Project storage project = projects[projectId];
    if (project.status != ProjectStatus.Active && project.status != ProjectStatus.Defaulted) {
      revert NotInActiveStatus();
    }
    if (msg.sender != project.host && msg.sender != address(loanManager)) {
      revert OnlyHostOrLoanManager();
    }

    (uint256 hostPercent, uint256 investorPercent) = loanManager.calculateEquitySplit(projectId);

    uint256 hostAmount = (offerAmount * hostPercent) / 100;
    uint256 investorAmount = (offerAmount * investorPercent) / 100;

    USDC.safeTransferFrom(msg.sender, address(this), offerAmount);

    if (hostAmount > 0) {
      USDC.safeTransfer(project.host, hostAmount);
    }

    _distributeBuyoutToInvestors(projectId, investorAmount);

    project.isBoughtOut = true;
    project.status = ProjectStatus.BoughtOut;

    emit BuyoutTriggered(projectId, offerAmount, hostAmount, investorAmount);
    emit ProjectStatusChanged(projectId, ProjectStatus.BoughtOut);
  }

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

  function getProjectHost(uint256 projectId) external view returns (address) {
    return projects[projectId].host;
  }

  /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  mapping(uint256 => uint256) public buyoutPerShare;
  mapping(uint256 => mapping(address => uint256)) public buyoutClaimed;

  function _distributeBuyoutToInvestors(uint256 projectId, uint256 investorAmount) internal {
    Project storage project = projects[projectId];
    if (project.totalShares > 0 && investorAmount > 0) {
      buyoutPerShare[projectId] += (investorAmount * 1e18) / project.totalShares;
    }
  }

  function claimBuyout(uint256 projectId) external returns (uint256 claimable) {
    uint256 shares = balanceOf(msg.sender, projectId);
    uint256 totalOwed = (shares * buyoutPerShare[projectId]) / 1e18;
    uint256 claimed = buyoutClaimed[projectId][msg.sender];
    claimable = totalOwed > claimed ? totalOwed - claimed : 0;

    require(claimable > 0, "Nothing to claim");
    buyoutClaimed[projectId][msg.sender] = totalOwed;
    _burn(msg.sender, projectId, shares);
    USDC.safeTransfer(msg.sender, claimable);
  }

  function getInvestorShares(
    uint256 projectId,
    address investor
  ) external view override returns (uint256) {
    return balanceOf(investor, projectId);
  }

  function getTotalShares(uint256 projectId) external view override returns (uint256) {
    return projects[projectId].totalShares;
  }
}
