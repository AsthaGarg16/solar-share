// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISolarProject} from "../interfaces/ISolarProject.sol";
import {IRevenueDistributor} from "../interfaces/IRevenueDistributor.sol";

contract RevenueDistributor is AccessControl, IRevenueDistributor {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

  error OnlyLoanManager();
  error OnlyGridOracle();
  error NothingToClaim();
  error InsufficientMaintenance();
  error InsufficientInsurance();

  /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

  event GridRevenueDeposited(uint256 indexed projectId, uint256 amount, uint256 timestamp);
  event HostPaymentDeposited(uint256 indexed projectId, uint256 amount, uint256 month);
  event WaterfallExecuted(
    uint256 indexed projectId,
    uint256 dividend,
    uint256 maintenance,
    uint256 insurance
  );

  /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
  bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

  struct RevenuePool {
    uint256 totalRevenue; // Undistributed revenue waiting for waterfall
    uint256 dividendPool; // 93% share
    uint256 maintenanceReserve; // 5% share
    uint256 insurancePool; // 2% share
    uint256 dividendPerShare; // Accumulator for pull-pattern
    uint256 currentMonth;
  }

  mapping(uint256 => RevenuePool) public projectRevenue;
  mapping(uint256 => mapping(address => uint256)) public claimedDividends;

  ISolarProject public immutable solarProject;
  IERC20 public immutable usdc;
  address public loanManager;
  address public gridOracle;

  uint256 public constant DIVIDEND_PERCENTAGE = 93;
  uint256 public constant MAINTENANCE_PERCENTAGE = 5;
  uint256 public constant PRECISION = 1e18;

  constructor(address _solarProject, address _usdc) {
    solarProject = ISolarProject(_solarProject);
    usdc = IERC20(_usdc);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MAINTAINER_ROLE, msg.sender);
  }

  /*//////////////////////////////////////////////////////////////
                           SETTERS
    //////////////////////////////////////////////////////////////*/
  function setLoanManager(address _loanManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
    loanManager = _loanManager;
  }

  function setGridOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
    gridOracle = _oracle;
  }

  /*//////////////////////////////////////////////////////////////
                           DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

  function depositGridRevenue(uint256 projectId, uint256 amount) external override {
    if (msg.sender != gridOracle) revert OnlyGridOracle();

    usdc.safeTransferFrom(msg.sender, address(this), amount);
    projectRevenue[projectId].totalRevenue += amount;

    emit GridRevenueDeposited(projectId, amount, block.timestamp);

    // Auto-execute waterfall
    _executeWaterfallInternal(projectId);
  }

  function depositHostPayment(uint256 projectId, uint256 amount) external override {
    if (msg.sender != loanManager) revert OnlyLoanManager();

    usdc.safeTransferFrom(msg.sender, address(this), amount);
    projectRevenue[projectId].totalRevenue += amount;
    projectRevenue[projectId].currentMonth += 1;

    emit HostPaymentDeposited(projectId, amount, projectRevenue[projectId].currentMonth);

    _executeWaterfallInternal(projectId);
  }

  /*//////////////////////////////////////////////////////////////
                           WATERFALL LOGIC
    //////////////////////////////////////////////////////////////*/

  function executeWaterfall(uint256 projectId) external override {
    _executeWaterfallInternal(projectId);
  }

  function _executeWaterfallInternal(uint256 projectId) internal {
    RevenuePool storage pool = projectRevenue[projectId];
    uint256 total = pool.totalRevenue;
    if (total == 0) return;

    uint256 dividendAmount = (total * DIVIDEND_PERCENTAGE) / 100;
    uint256 maintenanceAmount = (total * MAINTENANCE_PERCENTAGE) / 100;
    uint256 insuranceAmount = total - dividendAmount - maintenanceAmount;

    pool.dividendPool += dividendAmount;
    pool.maintenanceReserve += maintenanceAmount;
    pool.insurancePool += insuranceAmount;

    uint256 totalShares = solarProject.getTotalShares(projectId);
    if (totalShares > 0) {
      pool.dividendPerShare += (dividendAmount * PRECISION) / totalShares;
    }

    pool.totalRevenue = 0;

    emit WaterfallExecuted(projectId, dividendAmount, maintenanceAmount, insuranceAmount);
  }

  /*//////////////////////////////////////////////////////////////
                           CLAIMING & WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

  function claimDividends(uint256 projectId) external override returns (uint256 claimed) {
    uint256 shares = solarProject.getInvestorShares(projectId, msg.sender);
    RevenuePool storage pool = projectRevenue[projectId];

    uint256 totalOwed = (shares * pool.dividendPerShare) / PRECISION;
    uint256 alreadyClaimed = claimedDividends[projectId][msg.sender];

    if (totalOwed <= alreadyClaimed) revert NothingToClaim();
    claimed = totalOwed - alreadyClaimed;

    claimedDividends[projectId][msg.sender] = totalOwed;
    usdc.safeTransfer(msg.sender, claimed);
  }

  function withdrawMaintenance(
    uint256 projectId,
    uint256 amount,
    address recipient
  ) external override onlyRole(MAINTAINER_ROLE) {
    RevenuePool storage pool = projectRevenue[projectId];
    if (pool.maintenanceReserve < amount) revert InsufficientMaintenance();

    pool.maintenanceReserve -= amount;
    usdc.safeTransfer(recipient, amount);
  }

  function getClaimableDividends(
    uint256 projectId,
    address investor
  ) external view override returns (uint256) {
    uint256 shares = solarProject.getInvestorShares(projectId, investor);
    uint256 totalOwed = (shares * projectRevenue[projectId].dividendPerShare) / PRECISION;
    uint256 alreadyClaimed = claimedDividends[projectId][investor];
    return totalOwed > alreadyClaimed ? totalOwed - alreadyClaimed : 0;
  }

  function settleCompletedProject(uint256) external pure override {}

  function getMaintenanceReserve(uint256 projectId) external view override returns (uint256) {
    return projectRevenue[projectId].maintenanceReserve;
  }

  function withdrawInsurance(
    uint256 projectId,
    uint256 amount
  ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    RevenuePool storage pool = projectRevenue[projectId];
    if (pool.insurancePool < amount) revert InsufficientInsurance();

    pool.insurancePool -= amount;
    usdc.safeTransfer(msg.sender, amount);
  }
}
