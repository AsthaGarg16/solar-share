// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISolarProject } from "../interfaces/ISolarProject.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";
import { IHostReputation } from "../interfaces/IHostReputation.sol";
import { IOracles } from "../interfaces/IOracles.sol"; // Use the generic IOracles interface
import { ILoanManager } from "../interfaces/ILoanManager.sol";

/// @title LoanManager - Track payments, detect defaults, calculate equity splits
contract LoanManager is Ownable, ILoanManager {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LoanAlreadyInitialized();
    error ProjectNotActive();
    error LoanNotInitialized();
    error AlreadyDefaulted();
    error LoanAlreadyCompleted();
    error NotProjectHost();
    error NotInDefault();
    error InDefault();
    error InvalidMonthlyPayment();
    error RevenueDistributorNotSet();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LoanInitialized(uint256 indexed projectId, uint256 monthlyPayment, uint256 termMonths);
    event PaymentReceived(uint256 indexed projectId, uint256 month, uint256 amount, uint256 timestamp);
    event DefaultDeclared(uint256 indexed projectId, uint256 missedMonth, address host);
    event DefaultExcused(uint256 indexed projectId, uint256 rainyDays, uint256 newDueDate);
    event LoanCompleted(uint256 indexed projectId, uint256 totalPaid);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    struct LoanDetails {
        uint256 projectId;
        uint256 monthlyPayment;
        uint256 termMonths;
        uint256 currentMonth;
        uint256 lastPaymentDate;
        uint256 nextPaymentDue;
        uint256 totalPaid;
        uint256 totalOwed;
        bool isDefaulted;
        bool isCompleted;
        bool initialized;
    }

    mapping(uint256 => LoanDetails) public projectLoans;

    ISolarProject public immutable SOLAR_PROJECT;
    IRevenueDistributor public REVENUE_DISTRIBUTOR;
    IHostReputation public immutable HOST_REPUTATION;
    IERC20 public immutable USDC;

    // --- ORACLE INTERFACES ---
    IOracles public weatherOracle;
    IOracles public gridOracle;
    IOracles public iotOracle;

    uint256 public constant PAYMENT_GRACE_PERIOD = 30 days;
    uint256 public constant DEFAULT_PENALTY = 200;
    
    // Threshold for weather-based forgiveness
    uint256 public constant RAINY_DAY_THRESHOLD = 15;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // FIXED: Now accepts 6 arguments to match BaseTest.t.sol and Oracle requirements
    constructor(
        address _solarProject, 
        address _usdc, 
        address _hostReputation,
        address _weather,
        address _grid,
        address _iot
    ) Ownable(msg.sender) {
        SOLAR_PROJECT = ISolarProject(_solarProject);
        USDC = IERC20(_usdc);
        HOST_REPUTATION = IHostReputation(_hostReputation);
        
        // Link the oracles
        weatherOracle = IOracles(_weather);
        gridOracle = IOracles(_grid);
        iotOracle = IOracles(_iot);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRevenueDistributor(address _distributor) external override onlyOwner {
        REVENUE_DISTRIBUTOR = IRevenueDistributor(_distributor);
    }

    // --- REFINED SETTERS ---
    function setIoTOracle(address _iotOracle) external override onlyOwner {
        iotOracle = IOracles(_iotOracle);
    }

    function setAutomation(address /* _automation */) external override onlyOwner {
        // Implementation for automation logic if needed
    }

    /// @notice Initialize loan for a funded project
    function initializeLoan(uint256 projectId, uint256 monthlyPayment, uint256 termMonths)
        external
        override
    {
        LoanDetails storage loan = projectLoans[projectId];
        if (loan.initialized) revert LoanAlreadyInitialized();
        if (monthlyPayment == 0) revert InvalidMonthlyPayment();

        ISolarProject.Project memory project = SOLAR_PROJECT.getProjectDetails(projectId);
        if (project.status != ISolarProject.ProjectStatus.Active) {
            revert ProjectNotActive();
        }

        loan.projectId = projectId;
        loan.monthlyPayment = monthlyPayment;
        loan.termMonths = termMonths;
        loan.currentMonth = 0;
        loan.totalOwed = monthlyPayment * termMonths;
        loan.nextPaymentDue = block.timestamp + PAYMENT_GRACE_PERIOD;
        loan.initialized = true;

        emit LoanInitialized(projectId, monthlyPayment, termMonths);
    }

    /// @notice Host makes monthly payment
    function payMonthlyInstallment(uint256 projectId) external override {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized) revert LoanNotInitialized();
        if (loan.isDefaulted) revert InDefault();
        if (loan.isCompleted) revert LoanAlreadyCompleted();

        address host = SOLAR_PROJECT.getProjectHost(projectId);
        if (msg.sender != host) revert NotProjectHost();
        if (address(REVENUE_DISTRIBUTOR) == address(0)) {
            revert RevenueDistributorNotSet();
        }

        uint256 payment = loan.monthlyPayment;

        loan.currentMonth += 1;
        loan.lastPaymentDate = block.timestamp;
        loan.nextPaymentDue = block.timestamp + PAYMENT_GRACE_PERIOD;
        loan.totalPaid += payment;

        USDC.safeTransferFrom(msg.sender, address(this), payment);
        USDC.approve(address(REVENUE_DISTRIBUTOR), payment);
        REVENUE_DISTRIBUTOR.depositHostPayment(projectId, payment);

        emit PaymentReceived(projectId, loan.currentMonth, payment, block.timestamp);

        if (loan.totalPaid >= loan.totalOwed) {
            loan.isCompleted = true;
            emit LoanCompleted(projectId, loan.totalPaid);
        }
    }

    function checkDefaultStatus(uint256 projectId) external view override returns (bool isDefault) {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized || loan.isCompleted) return false;
        if (loan.isDefaulted) return true;
        return block.timestamp > loan.nextPaymentDue;
    }

    function declareDefault(uint256 projectId) external override {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized) revert LoanNotInitialized();
        if (loan.isDefaulted) revert AlreadyDefaulted();
        if (loan.isCompleted) revert LoanAlreadyCompleted();
        if (block.timestamp <= loan.nextPaymentDue) revert NotInDefault();

        // 1. Weather Check (Parametric Logic)
        uint256 rainyDays = weatherOracle.getRainyDays(projectId);
        if (rainyDays > RAINY_DAY_THRESHOLD) {
            loan.nextPaymentDue = block.timestamp + PAYMENT_GRACE_PERIOD;
            emit DefaultExcused(projectId, rainyDays, loan.nextPaymentDue);
            return;
        }

        // 2. Punishment Logic
        loan.isDefaulted = true;
        address host = SOLAR_PROJECT.getProjectHost(projectId);

        HOST_REPUTATION.slashScore(host, DEFAULT_PENALTY);
        SOLAR_PROJECT.setProjectDefaulted(projectId);

        // 3. TRIGGER IOT KILLSWITCH through the IOracles interface
        if (address(iotOracle) != address(0)) {
            iotOracle.triggerHardwareLock(projectId);
        }

        emit DefaultDeclared(projectId, loan.currentMonth + 1, host);
    }

    function calculateEquitySplit(uint256 projectId)
        external
        view
        override
        returns (uint256 hostPercent, uint256 investorPercent)
    {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized || loan.termMonths == 0) {
            return (0, 100);
        }

        hostPercent = (loan.currentMonth * 100) / loan.termMonths;
        if (hostPercent > 100) hostPercent = 100;
        investorPercent = 100 - hostPercent;
    }

    function getCurrentMonth(uint256 projectId) external view override returns (uint256) {
        return projectLoans[projectId].currentMonth;
    }
}