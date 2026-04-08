// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockGridOracle} from "../src/mocks/MockGridOracle.sol";
import {MockChainlinkKeeper} from "../src/mocks/MockChainlinkKeeper.sol";
import {SolarProject} from "../src/core/SolarProject.sol";
import {LoanManager} from "../src/core/LoanManager.sol";
import {RevenueDistributor} from "../src/core/RevenueDistributor.sol";
import {HostReputation} from "../src/core/HostReputation.sol";
import {MaintenanceDAO} from "../src/core/MaintenanceDAO.sol";
import {MockIoTSolarOracle} from "../src/mocks/MockIoTSolarOracle.sol";
import {MockWeatherOracle} from "../src/mocks/MockWeatherOracle.sol";

contract BaseTest is Test {
  MockUSDC public usdc;
  SolarProject public solarProject;
  LoanManager public loanManager;
  RevenueDistributor public distributor;
  HostReputation public reputation;
  MockWeatherOracle public weatherOracle;
  MockGridOracle public gridOracle;
  MockIoTSolarOracle public iotOracle;
  MockGridOracle public oracle;
  MockChainlinkKeeper public keeper;
  MaintenanceDAO public dao;

  address public owner = makeAddr("owner");
  address public host = makeAddr("host");
  address public investor1 = makeAddr("investor1");
  address public investor2 = makeAddr("investor2");
  address public investor3 = makeAddr("investor3");
  address public vendor = makeAddr("vendor");

  uint256 public constant TARGET_AMOUNT = 20_000 * 10 ** 6;
  uint256 public constant TERM_MONTHS = 120;
  uint256 public constant TOTAL_SHARES = 1000;
  uint256 public constant MONTHLY_PAYMENT = TARGET_AMOUNT / TERM_MONTHS;
  uint256 public constant INITIAL_USDC = 100_000 * 10 ** 6;

  function setUp() public virtual {
    vm.startPrank(owner);

    // 1. Deploy Mocks & Base
    usdc = new MockUSDC();
    reputation = new HostReputation();
    solarProject = new SolarProject(address(usdc));
    weatherOracle = new MockWeatherOracle();
    iotOracle = new MockIoTSolarOracle();

    // Use this instance for EVERYTHING
    gridOracle = new MockGridOracle(address(usdc), address(0));

    // 2. Deploy Core Logic
    loanManager = new LoanManager(
      address(solarProject),
      address(usdc),
      address(reputation),
      address(weatherOracle),
      address(gridOracle),
      address(iotOracle)
    );

    distributor = new RevenueDistributor(address(solarProject), address(usdc));
    dao = new MaintenanceDAO(
      address(solarProject),
      address(distributor),
      address(usdc),
      address(weatherOracle)
    );

    // 3. Wire up dependencies
    loanManager.setRevenueDistributor(address(distributor));
    distributor.setLoanManager(address(loanManager));
    solarProject.setLoanManager(address(loanManager));

    // 4. Grant Roles (The Keccak fix)
    reputation.grantRole(keccak256("SLASHER_ROLE"), address(loanManager));
    distributor.grantRole(keccak256("MAINTAINER_ROLE"), address(dao));
    distributor.grantRole(keccak256("GRID_ORACLE_ROLE"), address(gridOracle));
    distributor.setGridOracle(address(gridOracle));

    // 5. Deploy Keepers
    keeper = new MockChainlinkKeeper(address(loanManager));

    // Assign the same instance to the 'oracle' variable if other tests use that name
    oracle = gridOracle;

    vm.stopPrank();

    // 6. Funding
    _fundUser(host, INITIAL_USDC);
    _fundUser(investor1, INITIAL_USDC);
    _fundUser(investor2, INITIAL_USDC);
    _fundUser(investor3, INITIAL_USDC);

    // Fund the authorized oracle address
    _fundUser(address(gridOracle), 10_000 * 10 ** 6);
  }

  function _fundUser(address user, uint256 amount) internal {
    vm.prank(owner);
    usdc.mint(user, amount);
  }

  function _createProject() internal returns (uint256) {
    vm.prank(host);
    return solarProject.initializeProject("Solar Demo", TARGET_AMOUNT, TERM_MONTHS, TOTAL_SHARES);
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
    solarProject.withdrawFunds(projectId);
  }

  function _setupFullProject() internal returns (uint256 projectId) {
    projectId = _fundProjectFully();
    weatherOracle.setRainyDays(projectId, 0);
    _initializeLoan(projectId);
  }

  function _generateMaintenanceReserve(uint256 projectId, uint256 revenueAmount) internal virtual {
    vm.startPrank(address(gridOracle));
    usdc.mint(address(gridOracle), revenueAmount);
    usdc.approve(address(distributor), revenueAmount);
    distributor.depositGridRevenue(projectId, revenueAmount);
    distributor.executeWaterfall(projectId);
    vm.stopPrank();
  }
}
