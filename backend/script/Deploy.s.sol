// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {SolarProject} from "../src/core/SolarProject.sol";
import {LoanManager} from "../src/core/LoanManager.sol";
import {RevenueDistributor} from "../src/core/RevenueDistributor.sol";
import {HostReputation} from "../src/core/HostReputation.sol";
import {MaintenanceDAO} from "../src/core/MaintenanceDAO.sol";
import {MockGridOracle} from "../src/mocks/MockGridOracle.sol";
import {MockIoTSolarOracle} from "../src/mocks/MockIoTSolarOracle.sol";
import {IIoTSolarOracle} from "../src/interfaces/IIoTSolarOracle.sol";
import {IoTSolarOracle} from "../src/oracles/IoTSolarOracle.sol";
import {WeatherOracle} from "../src/oracles/WeatherOracle.sol";
import {LoanAutomation} from "../src/oracles/LoanAutomation.sol";

contract DeployScript is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
    if (deployerPrivateKey != 0) {
      vm.startBroadcast(deployerPrivateKey);
    } else {
      // Allows running with `forge script ... --private-key ... --broadcast` without exporting PRIVATE_KEY
      vm.startBroadcast();
    }

    // 1. Deploy MockUSDC
    MockUSDC usdc = new MockUSDC();
    console.log("MockUSDC deployed:", address(usdc));

    // 2. Deploy HostReputation
    HostReputation reputation = new HostReputation();
    console.log("HostReputation deployed:", address(reputation));

    // 3. Deploy SolarProject
    SolarProject solarProject = new SolarProject(address(usdc));
    console.log("SolarProject deployed:", address(solarProject));

    // --- ORACLE SETUP (Moved up so LoanManager can use them) ---
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint64 subId = 1;

    RevenueDistributor distributor = new RevenueDistributor(address(solarProject), address(usdc));
    WeatherOracle weatherOracle = new WeatherOracle(router, donId, subId);
    // Using distributor address(0) initially as it's not deployed yet, or use gridOracle.setDistributor later
    MockGridOracle gridOracle = new MockGridOracle(address(usdc), address(distributor));

    IIoTSolarOracle iotOracle;
    if (block.chainid == 31337) {
      iotOracle = new MockIoTSolarOracle();
    } else {
      iotOracle = IIoTSolarOracle(address(new IoTSolarOracle(router, donId, subId)));
    }

    // 4. Deploy LoanManager (Now identifiers are declared)
    LoanManager loanManager = new LoanManager(
      address(solarProject),
      address(usdc),
      address(reputation),
      address(weatherOracle),
      address(gridOracle),
      address(iotOracle)
    );
    console.log("LoanManager deployed:", address(loanManager));

    // 5. Deploy RevenueDistributor
    console.log("RevenueDistributor deployed:", address(distributor));

    // 6. Wire up contracts
    loanManager.setRevenueDistributor(address(distributor));
    distributor.setLoanManager(address(loanManager));
    solarProject.setLoanManager(address(loanManager));
    distributor.setGridOracle(address(gridOracle));

    // Prefund the mock grid oracle so it can deposit revenue into the distributor on localhost.
    // (depositGridRevenue pulls USDC via transferFrom(msg.sender,...))
    usdc.transfer(address(gridOracle), 100_000 * 10 ** 6);

    // 7. Grant SLASHER_ROLE to LoanManager
    bytes32 slasherRole = reputation.SLASHER_ROLE();
    reputation.grantRole(slasherRole, address(loanManager));

    // 8. Deploy MaintenanceDAO
    MaintenanceDAO dao = new MaintenanceDAO(
      address(solarProject),
      address(distributor),
      address(usdc),
      address(weatherOracle)
    );
    console.log("MaintenanceDAO deployed:", address(dao));

    // Allow the DAO to trigger weather checks (optional for local demo).
    weatherOracle.setMaintenanceDao(address(dao));

    // Grant MAINTAINER_ROLE to MaintenanceDAO
    bytes32 maintainerRole = distributor.MAINTAINER_ROLE();
    distributor.grantRole(maintainerRole, address(dao));

    // 12. Deploy Automation / Keeper
    LoanAutomation automation = new LoanAutomation(address(loanManager));
    console.log("LoanAutomation deployed:", address(automation));

    vm.stopBroadcast();

    // Write addresses to deployments/<chainId>.json
    string memory json = "addresses";
    vm.serializeAddress(json, "mockUSDC", address(usdc));
    vm.serializeAddress(json, "hostReputation", address(reputation));
    vm.serializeAddress(json, "solarProject", address(solarProject));
    vm.serializeAddress(json, "loanManager", address(loanManager));
    vm.serializeAddress(json, "revenueDistributor", address(distributor));
    vm.serializeAddress(json, "maintenanceDAO", address(dao));
    vm.serializeAddress(json, "mockGridOracle", address(gridOracle));
    vm.serializeAddress(json, "iotSolarOracle", address(iotOracle));
    vm.serializeAddress(json, "weatherOracle", address(weatherOracle));
    string memory finalJson = vm.serializeAddress(json, "mockKeeper", address(automation));
    vm.writeJson(finalJson, string.concat("./deployments/", vm.toString(block.chainid), ".json"));
    console.log("Addresses saved to deployments/<chainId>.json");

    console.log("\n=== Deployment Complete ===");
  }
}
