// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {SolarProject} from "../src/core/SolarProject.sol";
import {LoanManager} from "../src/core/LoanManager.sol";
import {RevenueDistributor} from "../src/core/RevenueDistributor.sol";
import {HostReputation} from "../src/core/HostReputation.sol";
import {MaintenanceDAO} from "../src/core/MaintenanceDAO.sol";

// UPDATED: Pointing to the new Oracle and its interface
import {SolarRevenueOracle} from "../src/oracles/SolarRevenueOracle.sol";
import {ISolarRevenueOracle} from "../src/interfaces/oracle-interfaces/ISolarRevenueOracle.sol";

contract BaseTest is Test {
    MockUSDC public usdc;
    SolarProject public solarProject;
    LoanManager public loanManager;
    RevenueDistributor public distributor;
    HostReputation public reputation;
    MaintenanceDAO public dao;
    
    // UPDATED: Variable type changed to the new name
    SolarRevenueOracle public oracle;

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

        // 1. Deploy Core
        usdc = new MockUSDC();
        reputation = new HostReputation();
        solarProject = new SolarProject(address(usdc));
        loanManager = new LoanManager(address(solarProject), address(usdc), address(reputation));
        distributor = new RevenueDistributor(address(solarProject), address(usdc));
        dao = new MaintenanceDAO(address(solarProject), address(distributor), address(usdc));

        // 2. Wire up contracts
        loanManager.setRevenueDistributor(address(distributor));
        distributor.setLoanManager(address(loanManager));
        solarProject.setLoanManager(address(loanManager));

        // 3. Setup Roles
        reputation.grantRole(reputation.SLASHER_ROLE(), address(loanManager));
        distributor.grantRole(distributor.MAINTAINER_ROLE(), address(dao));

        // 4. UPDATED: Deploy the new SolarRevenueOracle
        oracle = new SolarRevenueOracle(address(usdc), address(distributor));
        distributor.setGridOracle(address(oracle));

        vm.stopPrank();

        // 5. Fund test users
        _fundUser(host, INITIAL_USDC);
        _fundUser(investor1, INITIAL_USDC);
        _fundUser(investor2, INITIAL_USDC);
        _fundUser(investor3, INITIAL_USDC);
        
        // 6. IMPORTANT: Fund the oracle so it can "push" USDC revenue during tests
        _fundUser(address(oracle), 100_000 * 10 ** 6);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _fundUser(address user, uint256 amount) internal {
        vm.prank(owner);
        usdc.mint(user, amount);
    }

    function _createProject() internal returns (uint256 projectId) {
        vm.prank(host);
        // Added the 4th argument (Hardware ID) to match SolarProject.sol
        projectId = solarProject.initializeProject(TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES, "ENPHASE_123");
    }

    function _fundProjectFully() internal returns (uint256 projectId) {
        projectId = _createProject();
        
        vm.startPrank(investor1);
        usdc.approve(address(solarProject), 10_000 * 10 ** 6);
        solarProject.fundProject(projectId, 500);
        vm.stopPrank();

        vm.startPrank(investor2);
        usdc.approve(address(solarProject), 6_000 * 10 ** 6);
        solarProject.fundProject(projectId, 300);
        vm.stopPrank();

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
        vm.startPrank(address(oracle)); // Simulating the oracle as the sender
        usdc.approve(address(distributor), revenueAmount);
        distributor.depositGridRevenue(projectId, revenueAmount);
        vm.stopPrank();
        
        distributor.executeWaterfall(projectId);
    }
}
