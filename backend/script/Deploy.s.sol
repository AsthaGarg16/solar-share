// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {SolarProject} from "../src/core/SolarProject.sol";
import {LoanManager} from "../src/core/LoanManager.sol";
import {RevenueDistributor} from "../src/core/RevenueDistributor.sol";
import {HostReputation} from "../src/core/HostReputation.sol";
import {MaintenanceDAO} from "../src/core/MaintenanceDAO.sol";
import {SolarRevenueOracle} from "../src/oracles/SolarRevenueOracle.sol";

// Import the new Real Oracles
import {IoTSolarOracle} from "../src/oracles/IoTSolarOracle.sol";
import {WeatherOracle} from "../src/oracles/WeatherOracle.sol";
import {LoanAutomation} from "../src/oracles/LoanAutomation.sol"; // Real LoanAutomation contract that replaced the MockChainlinkKeeper.sol in mocks folder

contract DeployScript is Script {
    function run() external {

        // =============================================================
        // CHAINLINK SEPOLIA CONFIGURATION
        // =============================================================
        address functionsRouter = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
        bytes32 donId = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
        address usdcUsdPriceFeed = 0xA2f78aB2355fe2F984d808B5cEe7FDeD358150BA; // Sepolia USDC/USD Feed
        
        // We use envOr so it defaults to 0 during local testing if not set
        uint64 subId = uint64(vm.envOr("CHAINLINK_SUB_ID", uint256(0))); 

        vm.startBroadcast();

        // 1. Deploy MockUSDC
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed:", address(usdc));

        // 2. Deploy HostReputation
        HostReputation reputation = new HostReputation();
        console.log("HostReputation deployed:", address(reputation));

        // 3. Deploy SolarProject
        SolarProject solarProject = new SolarProject(address(usdc));
        console.log("SolarProject deployed:", address(solarProject));

        // 4. Deploy LoanManager
        LoanManager loanManager = new LoanManager(address(solarProject), address(usdc), address(reputation));
        console.log("LoanManager deployed:", address(loanManager));

        // 5. Deploy RevenueDistributor
        RevenueDistributor distributor = new RevenueDistributor(address(solarProject), address(usdc));
        console.log("RevenueDistributor deployed:", address(distributor));

        // 6. Wire up core contracts
        loanManager.setRevenueDistributor(address(distributor));
        distributor.setLoanManager(address(loanManager));
        solarProject.setLoanManager(address(loanManager));

        // Grant SLASHER_ROLE to LoanManager
        bytes32 slasherRole = reputation.SLASHER_ROLE();
        reputation.grantRole(slasherRole, address(loanManager));

        // 7. Deploy MaintenanceDAO
        MaintenanceDAO dao = new MaintenanceDAO(address(solarProject), address(distributor), address(usdc));
        console.log("MaintenanceDAO deployed:", address(dao));

        // Grant MAINTAINER_ROLE to MaintenanceDAO
        bytes32 maintainerRole = distributor.MAINTAINER_ROLE();
        distributor.grantRole(maintainerRole, address(dao));

        // 8. Deploy MockGridOracle (Still used to simulate the actual generation of $20-$150)
        SolarRevenueOracle gridOracle = new SolarRevenueOracle(address(usdc), address(distributor));
        distributor.setGridOracle(address(gridOracle));
        console.log("SolarRevenueOracle deployed:", address(gridOracle));

        // =============================================================
        // 9. DEPLOY & WIRE REAL ORACLES
        // =============================================================

        // A. Link the Chainlink Price Feed to RevenueDistributor
        distributor.setDataFeed(usdcUsdPriceFeed);
        console.log("Price Feed linked to RevenueDistributor");

        // B. Deploy and link IoT Killswitch
        IoTSolarOracle iotOracle = new IoTSolarOracle(functionsRouter, donId, subId);
        iotOracle.setLoanManager(address(loanManager)); // Give Oracle permission
        loanManager.setIotOracle(address(iotOracle));   // Link Oracle to Manager
        console.log("IoTSolarOracle deployed:", address(iotOracle));

        // C. Deploy and link Weather Oracle
        WeatherOracle weatherOracle = new WeatherOracle(functionsRouter, donId, subId);
        weatherOracle.setMaintenanceDAO(address(dao));  // Give Oracle permission
        dao.setWeatherOracle(address(weatherOracle));   // Link Oracle to DAO
        console.log("WeatherOracle deployed:", address(weatherOracle));

        // D. Deploy Real Chainlink Automation (Replaces MockKeeper)
        LoanAutomation automation = new LoanAutomation(address(loanManager));
        console.log("LoanAutomation deployed:", address(automation));

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Network: Sepolia");
        console.log("Update .env with these addresses:");
        console.log("MOCK_USDC=", address(usdc));
        console.log("SOLAR_PROJECT=", address(solarProject));
        console.log("LOAN_MANAGER=", address(loanManager));
        console.log("REVENUE_DISTRIBUTOR=", address(distributor));
        console.log("HOST_REPUTATION=", address(reputation));
        console.log("MAINTENANCE_DAO=", address(dao));
        console.log("MOCK_GRID_ORACLE=", address(gridOracle));
        console.log("IOT_SOLAR_ORACLE=", address(iotOracle));
        console.log("WEATHER_ORACLE=", address(weatherOracle));
        console.log("LOAN_AUTOMATION=", address(automation));
    }
}