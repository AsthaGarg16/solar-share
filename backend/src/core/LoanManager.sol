// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISolarProject } from "../interfaces/ISolarProject.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";
import { IHostReputation } from "../interfaces/IHostReputation.sol";
import { ILoanManager } from "../interfaces/ILoanManager.sol";
import { SolarProject } from "./SolarProject.sol";
import "forge-std/console.sol";

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
    event PaymentReceived(
        uint256 indexed projectId, uint256 month, uint256 amount, uint256 timestamp
    );
    event DefaultDeclared(uint256 indexed projectId, uint256 missedMonth, address host);
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

    ISolarProject public immutable solarProject;
    IRevenueDistributor public revenueDistributor;
    IHostReputation public immutable hostReputation;
    IERC20 public immutable usdc;

    uint256 public constant PAYMENT_GRACE_PERIOD = 30 days;
    uint256 public constant DEFAULT_PENALTY = 200;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solarProject, address _usdc, address _hostReputation) Ownable(msg.sender) {
        solarProject = ISolarProject(_solarProject);
        usdc = IERC20(_usdc);
        hostReputation = IHostReputation(_hostReputation);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setRevenueDistributor(address _distributor) external override onlyOwner {
        revenueDistributor = IRevenueDistributor(_distributor);
    }

    /// @notice Initialize loan for a funded project
    function initializeLoan(uint256 projectId, uint256 monthlyPayment, uint256 termMonths)
        external
        override
    {
        console.log("--- Contract Call: initializeLoan ---");
        console.log("Project ID:", projectId);
        console.log("Monthly Payment:", monthlyPayment);
        LoanDetails storage loan = projectLoans[projectId];
        if (loan.initialized) revert LoanAlreadyInitialized();
        if (monthlyPayment == 0) revert InvalidMonthlyPayment();

        ISolarProject.Project memory project = solarProject.getProjectDetails(projectId);
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

        address host = solarProject.getProjectHost(projectId);
        if (msg.sender != host) revert NotProjectHost();
        if (address(revenueDistributor) == address(0)) {
            revert RevenueDistributorNotSet();
        }

        uint256 payment = loan.monthlyPayment;

        // CEI: Effects
        loan.currentMonth += 1;
        loan.lastPaymentDate = block.timestamp;
        loan.nextPaymentDue += PAYMENT_GRACE_PERIOD;
        loan.totalPaid += payment;

        // Transfer USDC from host -> this contract -> RevenueDistributor
        usdc.safeTransferFrom(msg.sender, address(this), payment);
        usdc.approve(address(revenueDistributor), payment);
        revenueDistributor.depositHostPayment(projectId, payment);

        emit PaymentReceived(projectId, loan.currentMonth, payment, block.timestamp);

        if (loan.totalPaid >= loan.totalOwed) {
            loan.isCompleted = true;
            emit LoanCompleted(projectId, loan.totalPaid);

            // TODO: Uncomment these lines for demo?
            // SolarProject.Project memory project = solarProject.getProjectDetails(projectId);
            // uint256 projectEndTime = project.startDate + (project.termMonths * 30 days);

            // if (block.timestamp >= projectEndTime) {
            //     solarProject.completeProject(projectId);
            // }
        }
    }

    /// @notice Check if project is in default (view)
    function checkDefaultStatus(uint256 projectId) external view override returns (bool isDefault) {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized) return false;
        if (loan.isDefaulted) return true;
        if (loan.isCompleted) return false;
        return block.timestamp > loan.nextPaymentDue;
    }

    /// @notice Declare default - callable by anyone if payment overdue
    function declareDefault(uint256 projectId) external override {
        LoanDetails storage loan = projectLoans[projectId];
        if (!loan.initialized) revert LoanNotInitialized();
        if (loan.isDefaulted) revert AlreadyDefaulted();
        if (loan.isCompleted) revert LoanAlreadyCompleted();
        if (block.timestamp <= loan.nextPaymentDue) revert NotInDefault();

        loan.isDefaulted = true;

        address host = solarProject.getProjectHost(projectId);

        // Slash host reputation
        hostReputation.slashScore(host, DEFAULT_PENALTY);

        // Update project status
        solarProject.setProjectDefaulted(projectId);

        emit DefaultDeclared(projectId, loan.currentMonth + 1, host);
    }

    /// @notice Calculate equity split based on linear amortization
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

    /// @notice Get current month for a project
    function getCurrentMonth(uint256 projectId) external view override returns (uint256) {
        return projectLoans[projectId].currentMonth;
    }
}
