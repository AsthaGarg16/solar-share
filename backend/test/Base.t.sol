// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockGridOracle} from "../src/mocks/MockGridOracle.sol";
import {MockChainlinkKeeper} from "../src/mocks/MockChainlinkKeeper.sol";
import {SolarProject} from "../src/core/SolarProject.sol";
import {LoanManager} from "../src/core/LoanManager.sol";
import {RevenueDistributor} from "../src/core/RevenueDistributor.sol";
import {HostReputation} from "../src/core/HostReputation.sol";
import {MaintenanceDAO} from "../src/core/MaintenanceDAO.sol";

contract BaseTest is Test {
    MockUSDC public usdc;
    SolarProject public solarProject;
    LoanManager public loanManager;
    RevenueDistributor public distributor;
    HostReputation public reputation;
    MockGridOracle public oracle;
    MockChainlinkKeeper public keeper;
    MaintenanceDAO public dao;

    address public owner = makeAddr("owner");
    address public host = makeAddr("host");
    address public investor1 = makeAddr("investor1");
    address public investor2 = makeAddr("investor2");
    address public investor3 = makeAddr("investor3");
    address public vendor = makeAddr("vendor");

    uint256 public constant TARGET_AMOUNT = 20_000 * 10 ** 6; // $20,000 USDC
    uint256 public constant TERM_MONTHS = 120;
    uint256 public constant TOTAL_SHARES = 1000;
    uint256 public constant MONTHLY_PAYMENT = 200 * 10 ** 6; // $200 USDC
    uint256 public constant INITIAL_USDC = 100_000 * 10 ** 6; // $100,000 per user

    function setUp() public virtual {
        vm.startPrank(owner);

        // Deploy contracts
        usdc = new MockUSDC();
        reputation = new HostReputation();
        solarProject = new SolarProject(address(usdc));
        loanManager = new LoanManager(address(solarProject), address(usdc), address(reputation));
        distributor = new RevenueDistributor(address(solarProject), address(usdc));
        dao = new MaintenanceDAO(address(solarProject), address(distributor), address(usdc));

        // Wire up contracts
        loanManager.setRevenueDistributor(address(distributor));
        distributor.setLoanManager(address(loanManager));
        solarProject.setLoanManager(address(loanManager));

        // Grant SLASHER_ROLE to LoanManager
        bytes32 slasherRole = reputation.SLASHER_ROLE();
        reputation.grantRole(slasherRole, address(loanManager));

        // Grant MAINTAINER_ROLE to MaintenanceDAO
        bytes32 maintainerRole = distributor.MAINTAINER_ROLE();
        distributor.grantRole(maintainerRole, address(dao));

        // Deploy mocks
        oracle = new MockGridOracle(address(usdc), address(distributor));
        keeper = new MockChainlinkKeeper(address(loanManager));

        vm.stopPrank();

        // Fund test users
        _fundUser(host, INITIAL_USDC);
        _fundUser(investor1, INITIAL_USDC);
        _fundUser(investor2, INITIAL_USDC);
        _fundUser(investor3, INITIAL_USDC);
        // Fund oracle with USDC for revenue submissions
        _fundUser(address(oracle), 10_000 * 10 ** 6);
    }

    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        usdc.mint(user, amount);
    }

    function _createProject() internal returns (uint256 projectId) {
        vm.prank(host);
        projectId = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
    }

    function _fundProjectFully() internal returns (uint256 projectId) {
        projectId = _createProject();
        // investor1: 500 shares ($10,000) = 50%
        vm.startPrank(investor1);
        usdc.approve(address(solarProject), 10_000 * 10 ** 6);
        solarProject.fundProject(projectId, 500);
        vm.stopPrank();

        // investor2: 300 shares ($6,000) = 30%
        vm.startPrank(investor2);
        usdc.approve(address(solarProject), 6_000 * 10 ** 6);
        solarProject.fundProject(projectId, 300);
        vm.stopPrank();

        // investor3: 200 shares ($4,000) = 20%
        vm.startPrank(investor3);
        usdc.approve(address(solarProject), 4_000 * 10 ** 6);
        solarProject.fundProject(projectId, 200);
        vm.stopPrank();
    }

    function _initializeLoan(uint256 projectId) internal {
        vm.prank(host);
        loanManager.initializeLoan(projectId, MONTHLY_PAYMENT, TERM_MONTHS);
    }

    function _setupFullProject() internal returns (uint256 projectId) {
        projectId = _fundProjectFully();
        _initializeLoan(projectId);
    }

    /// @dev Generate maintenance reserve by depositing revenue and executing waterfall
    function _generateMaintenanceReserve(uint256 projectId, uint256 revenueAmount) internal {
        vm.startPrank(owner);
        usdc.mint(owner, revenueAmount);
        usdc.approve(address(distributor), revenueAmount);
        distributor.depositGridRevenue(projectId, revenueAmount);
        vm.stopPrank();
        distributor.executeWaterfall(projectId);
    }
}
