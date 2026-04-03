// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SolarRevenueOracle} from "../src/oracles/SolarRevenueOracle.sol";

contract SimulateRevenue is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("SOLAR_REVENUE_ORACLE");
        uint256 projectId = vm.envOr("PROJECT_ID", uint256(1));

        SolarRevenueOracle oracle = SolarRevenueOracle(oracleAddress);

        vm.startBroadcast(deployerPrivateKey);
        console.log("Submitting grid revenue for project:", projectId);
        oracle.submitGridRevenue(projectId);
        console.log("Revenue submitted at:", block.timestamp);
        vm.stopBroadcast();
    }
}
