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
import {MockChainlinkKeeper} from "../src/mocks/MockChainlinkKeeper.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

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

        // 6. Wire up contracts
        loanManager.setRevenueDistributor(address(distributor));
        distributor.setLoanManager(address(loanManager));
        solarProject.setLoanManager(address(loanManager));

        // 7. Grant SLASHER_ROLE to LoanManager
        bytes32 slasherRole = reputation.SLASHER_ROLE();
        reputation.grantRole(slasherRole, address(loanManager));

        // 8. Deploy MaintenanceDAO
        MaintenanceDAO dao = new MaintenanceDAO(address(solarProject), address(distributor), address(usdc));
        console.log("MaintenanceDAO deployed:", address(dao));

        // Grant MAINTAINER_ROLE to MaintenanceDAO
        bytes32 maintainerRole = distributor.MAINTAINER_ROLE();
        distributor.grantRole(maintainerRole, address(dao));

        // 9. Deploy MockGridOracle
        MockGridOracle oracle = new MockGridOracle(address(usdc), address(distributor));
        console.log("MockGridOracle deployed:", address(oracle));

        // 10. Deploy MockChainlinkKeeper
        MockChainlinkKeeper keeper = new MockChainlinkKeeper(address(loanManager));
        console.log("MockKeeper deployed:", address(keeper));

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
        console.log("MOCK_GRID_ORACLE=", address(oracle));
        console.log("MOCK_KEEPER=", address(keeper));
    }
}
