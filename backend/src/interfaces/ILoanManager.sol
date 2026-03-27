// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILoanManager {
    function initializeLoan(uint256 projectId, uint256 monthlyPayment, uint256 termMonths) external;

    function payMonthlyInstallment(uint256 projectId) external;

    function checkDefaultStatus(uint256 projectId) external view returns (bool isDefault);

    function declareDefault(uint256 projectId) external;

    function calculateEquitySplit(uint256 projectId)
        external
        view
        returns (uint256 hostPercent, uint256 investorPercent);

    function getCurrentMonth(uint256 projectId) external view returns (uint256);

    function setRevenueDistributor(address _distributor) external;
}
