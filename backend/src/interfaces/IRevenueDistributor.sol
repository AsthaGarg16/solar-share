// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRevenueDistributor {
    function depositGridRevenue(uint256 projectId, uint256 amount) external;

    function depositHostPayment(uint256 projectId, uint256 amount) external;

    function executeWaterfall(uint256 projectId) external;

    function claimDividends(uint256 projectId) external returns (uint256 claimed);

    function getClaimableDividends(uint256 projectId, address investor)
        external
        view
        returns (uint256 claimable);

    function withdrawMaintenance(uint256 projectId, uint256 amount, address recipient) external;

    function withdrawInsurance(uint256 projectId, uint256 amount) external;

    function setLoanManager(address _loanManager) external;

    function getMaintenanceReserve(uint256 projectId) external view returns (uint256);

    function settleCompletedProject(uint256 projectId) external;
}
