// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISolarProject {
    enum ProjectStatus {
        Funding,
        Active,
        Defaulted,
        BoughtOut
    }

    struct Project {
        uint256 projectId;
        address host;
        string hardwareId;
        uint256 targetAmount;
        uint256 amountRaised;
        uint256 totalShares;
        uint256 sharesSold;
        uint256 pricePerShare;
        uint256 termMonths;
        uint256 startDate;
        bool isFunded;
        bool isBoughtOut;
        ProjectStatus status;
    }

    function initializeProject(uint256 targetAmount, uint256 termMonths, uint256 totalShares, string calldata hardwareId) external returns (uint256 projectId);

    function fundProject(uint256 projectId, uint256 numShares) external;

    function triggerBuyout(uint256 projectId, uint256 offerAmount) external;

    function getProjectDetails(uint256 projectId) external view returns (Project memory);

    function getInvestorShares(uint256 projectId, address investor) external view returns (uint256);

    function getTotalShares(uint256 projectId) external view returns (uint256);

    function getProjectHost(uint256 projectId) external view returns (address);

    function setProjectDefaulted(uint256 projectId) external;

    function completeProject(uint256 projectId) external;

    function getHardwareId(uint256 projectId) external view returns (string memory);
}
