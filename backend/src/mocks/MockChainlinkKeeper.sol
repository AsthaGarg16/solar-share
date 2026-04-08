// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILoanManager } from "../interfaces/ILoanManager.sol";

/// @notice Simulates Chainlink Automation for automated default detection
contract MockChainlinkKeeper {
    ILoanManager public immutable LOAN_MANAGER;
    uint256[] public monitoredProjects;

    event UpkeepPerformed(uint256 indexed projectId, bool defaulted);

    constructor(address _loanManager) {
        LOAN_MANAGER = ILoanManager(_loanManager);
    }

    function addProject(uint256 projectId) external {
        monitoredProjects.push(projectId);
    }

    /// @notice Check if any monitored project needs upkeep (default declaration)
    function checkUpkeep() external view returns (bool upkeepNeeded, uint256 projectId) {
        for (uint256 i = 0; i < monitoredProjects.length; i++) {
            if (LOAN_MANAGER.checkDefaultStatus(monitoredProjects[i])) {
                return (true, monitoredProjects[i]);
            }
        }
        return (false, 0);
    }

    /// @notice Perform upkeep: declare default for a project in default
    function performUpkeep(uint256 projectId) external {
        bool isDefault = LOAN_MANAGER.checkDefaultStatus(projectId);
        if (isDefault) {
            LOAN_MANAGER.declareDefault(projectId);
            emit UpkeepPerformed(projectId, true);
        } else {
            emit UpkeepPerformed(projectId, false);
        }
    }

    /// @notice Auto-check and perform upkeep for all monitored projects
    function performAutoUpkeep() external {
        for (uint256 i = 0; i < monitoredProjects.length; i++) {
            uint256 projectId = monitoredProjects[i];
            if (LOAN_MANAGER.checkDefaultStatus(projectId)) {
                LOAN_MANAGER.declareDefault(projectId);
                emit UpkeepPerformed(projectId, true);
            }
        }
    }
}
