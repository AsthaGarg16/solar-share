// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { MockGridOracle } from "../src/mocks/MockGridOracle.sol";

contract MockOracleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("MOCK_GRID_ORACLE");
        uint256 projectId = vm.envOr("PROJECT_ID", uint256(1));

        MockGridOracle oracle = MockGridOracle(oracleAddress);

        vm.startBroadcast(deployerPrivateKey);
        console.log("Submitting grid revenue for project:", projectId);
        oracle.submitGridRevenue(projectId);
        console.log("Revenue submitted at:", block.timestamp);
        vm.stopBroadcast();
    }
}
