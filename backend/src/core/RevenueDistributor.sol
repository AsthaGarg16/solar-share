// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISolarProject } from "../interfaces/ISolarProject.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";

/// @title RevenueDistributor - Routes revenue through 93/5/2 waterfall with pull-based dividends
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
    error LoanManagerNotSet();
    error GridOracleNotSet();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event GridRevenueDeposited(uint256 indexed projectId, uint256 amount, uint256 timestamp);
    event HostPaymentDeposited(uint256 indexed projectId, uint256 amount, uint256 month);
    event WaterfallExecuted(
        uint256 indexed projectId,
        uint256 totalRevenue,
        uint256 dividendAmount,
        uint256 maintenanceAmount,
        uint256 insuranceAmount
    );
    event DividendsClaimed(uint256 indexed projectId, address indexed investor, uint256 amount);
    event MaintenanceWithdrawn(uint256 indexed projectId, uint256 amount, address recipient);
    event InsuranceWithdrawn(uint256 indexed projectId, uint256 amount, address recipient);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    struct RevenuePool {
        uint256 totalRevenue;
        uint256 dividendPool;
        uint256 maintenanceReserve;
        uint256 insurancePool;
        uint256 dividendPerShare;
        uint256 lastWaterfallTimestamp;
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
    uint256 public constant INSURANCE_PERCENTAGE = 2;
    uint256 public constant PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solarProject, address _usdc) {
        solarProject = ISolarProject(_solarProject);
        usdc = IERC20(_usdc);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MAINTAINER_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setLoanManager(address _loanManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        loanManager = _loanManager;
    }

    function setGridOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        gridOracle = _oracle;
    }

    /// @notice Grid oracle deposits revenue
    function depositGridRevenue(uint256 projectId, uint256 amount) external override {
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        projectRevenue[projectId].totalRevenue += amount;
        emit GridRevenueDeposited(projectId, amount, block.timestamp);
    }

    /// @notice LoanManager deposits host payment (USDC already in LoanManager, transferred here)
    function depositHostPayment(uint256 projectId, uint256 amount) external override {
        if (msg.sender != loanManager) revert OnlyLoanManager();
        // USDC is transferred from host -> LoanManager -> here
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        projectRevenue[projectId].totalRevenue += amount;
        projectRevenue[projectId].currentMonth += 1;
        emit HostPaymentDeposited(projectId, amount, projectRevenue[projectId].currentMonth);
    }

    /// @notice Execute 93/5/2 waterfall split
    function executeWaterfall(uint256 projectId) external override {
        RevenuePool storage pool = projectRevenue[projectId];
        uint256 total = pool.totalRevenue;
        if (total == 0) return;

        uint256 dividendAmount = (total * DIVIDEND_PERCENTAGE) / 100;
        uint256 maintenanceAmount = (total * MAINTENANCE_PERCENTAGE) / 100;
        uint256 insuranceAmount = total - dividendAmount - maintenanceAmount; // avoids rounding dust

        pool.dividendPool += dividendAmount;
        pool.maintenanceReserve += maintenanceAmount;
        pool.insurancePool += insuranceAmount;

        // Update dividend-per-share accumulator (pull pattern)
        uint256 totalShares = solarProject.getTotalShares(projectId);
        if (totalShares > 0) {
            pool.dividendPerShare += (dividendAmount * PRECISION) / totalShares;
        }

        pool.totalRevenue = 0;
        pool.lastWaterfallTimestamp = block.timestamp;

        emit WaterfallExecuted(projectId, total, dividendAmount, maintenanceAmount, insuranceAmount);
    }

    /// @notice Investor claims accumulated dividends (pull pattern, O(1) gas)
    function claimDividends(uint256 projectId) external override returns (uint256 claimed) {
        uint256 shares = solarProject.getInvestorShares(projectId, msg.sender);
        RevenuePool storage pool = projectRevenue[projectId];

        uint256 totalOwed = (shares * pool.dividendPerShare) / PRECISION;
        uint256 alreadyClaimed = claimedDividends[projectId][msg.sender];

        claimed = totalOwed > alreadyClaimed ? totalOwed - alreadyClaimed : 0;
        if (claimed == 0) revert NothingToClaim();

        claimedDividends[projectId][msg.sender] = totalOwed;
        usdc.safeTransfer(msg.sender, claimed);

        emit DividendsClaimed(projectId, msg.sender, claimed);
    }

    /// @notice View claimable dividends for an investor
    function getClaimableDividends(uint256 projectId, address investor)
        external
        view
        override
        returns (uint256 claimable)
    {
        uint256 shares = solarProject.getInvestorShares(projectId, investor);
        uint256 totalOwed = (shares * projectRevenue[projectId].dividendPerShare) / PRECISION;
        uint256 alreadyClaimed = claimedDividends[projectId][investor];
        claimable = totalOwed > alreadyClaimed ? totalOwed - alreadyClaimed : 0;
    }

    /// @notice Get maintenance reserve for a project
    function getMaintenanceReserve(uint256 projectId) external view override returns (uint256) {
        return projectRevenue[projectId].maintenanceReserve;
    }

    /// @notice Withdraw from maintenance reserve - called by MaintenanceDAO
    function withdrawMaintenance(uint256 projectId, uint256 amount, address recipient)
        external
        override
        onlyRole(MAINTAINER_ROLE)
    {
        RevenuePool storage pool = projectRevenue[projectId];
        if (pool.maintenanceReserve < amount) revert InsufficientMaintenance();
        pool.maintenanceReserve -= amount;
        usdc.safeTransfer(recipient, amount);
        emit MaintenanceWithdrawn(projectId, amount, recipient);
    }

    /// @notice Withdraw from insurance pool (admin only)
    function withdrawInsurance(uint256 projectId, uint256 amount)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        RevenuePool storage pool = projectRevenue[projectId];
        if (pool.insurancePool < amount) revert InsufficientInsurance();
        pool.insurancePool -= amount;
        usdc.safeTransfer(msg.sender, amount);
        emit InsuranceWithdrawn(projectId, amount, msg.sender);
    }
}
