// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

interface ISimpleLoanManager {
    function checkDefaultStatus(uint256 projectId) external view returns (bool);
    function declareDefault(uint256 projectId) external;
}

contract LoanAutomation is AutomationCompatibleInterface {
    ISimpleLoanManager public immutable loanManager;
    uint256[] public projects;

    constructor(address _loanManager) {
        loanManager = ISimpleLoanManager(_loanManager);
    }

    function addProject(uint256 projectId) external {
        projects.push(projectId);
    }

    // 1. Chainlink nodes check this off-chain for free
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i = 0; i < projects.length; i++) {
            // Ask the LoanManager: "Is this guy late?"
            if (loanManager.checkDefaultStatus(projects[i])) {
                return (true, abi.encode(i, projects[i]));
            }
        }
        return (false, "");
    }

    // 2. Chainlink nodes submit this transaction if checkUpkeep returns true
    function performUpkeep(bytes calldata performData) external override {
        (uint256 index, uint256 projectId) = abi.decode(performData, (uint256, uint256));

        // Re-verify the status on-chain
        if (loanManager.checkDefaultStatus(projectId)) {
            // This call should handle the Weather Oracle check internally!
            loanManager.declareDefault(projectId);

            // Simple removal: Swap with last and pop
            projects[index] = projects[projects.length - 1];
            projects.pop();
        }
    }
}