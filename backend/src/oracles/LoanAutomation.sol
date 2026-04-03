// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {ILoanManager} from "../interfaces/ILoanManager.sol";

contract LoanAutomation is AutomationCompatibleInterface {
    ILoanManager public immutable loanManager;
    uint256[] public monitoredProjects;

    event UpkeepPerformed(uint256 indexed projectId, bool defaulted);

    constructor(address _loanManager) {
        loanManager = ILoanManager(_loanManager);
    }

    function addProject(uint256 projectId) external {
        monitoredProjects.push(projectId);
    }

    // 1. Chainlink nodes call this for FREE off-chain to see if work is needed
    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i = 0; i < monitoredProjects.length; i++) {
            if (loanManager.checkDefaultStatus(monitoredProjects[i])) {
                // If a project defaulted, tell the node it needs upkeep and pass the ID
                return (true, abi.encode(monitoredProjects[i])); 
            }
        }
        return (false, "");
    }

    // 2. If checkUpkeep was true, Chainlink nodes submit an on-chain transaction here
    function performUpkeep(bytes calldata performData) external override {
        uint256 projectId = abi.decode(performData, (uint256));
        
        // Double check it's actually in default before slashing!
        if (loanManager.checkDefaultStatus(projectId)) {
            loanManager.declareDefault(projectId);
            emit UpkeepPerformed(projectId, true);
        } else {
            emit UpkeepPerformed(projectId, false);
        }
    }
}