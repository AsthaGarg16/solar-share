// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracles } from "../interfaces/IOracles.sol";
import { IRevenueDistributor } from "../interfaces/IRevenueDistributor.sol";

contract GridOracle is FunctionsClient, Ownable, IOracles {
    using FunctionsRequest for FunctionsRequest.Request;

    // --- Chainlink Config ---
    bytes32 public donId;
    uint64 public subscriptionId;
    string public sourceCode;

    // --- System Core ---
    IERC20 public immutable USDC;
    IRevenueDistributor public immutable DISTRIBUTOR;
    address public loanManager;

    // projectId => monthIndex => kWh generated
    mapping(uint256 => mapping(uint256 => uint256)) public monthlyProduction;
    mapping(bytes32 => uint256) public requestToProject;

    constructor(
        address router,
        bytes32 _donId,
        uint64 _subscriptionId,
        address _usdc,
        address _distributor
    ) FunctionsClient(router) Ownable(msg.sender) {
        donId = _donId;
        subscriptionId = _subscriptionId;
        USDC = IERC20(_usdc);
        DISTRIBUTOR = IRevenueDistributor(_distributor);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE ORACLE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Chainlink Callback: Now handles the "Revenue Deposit" logic
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err)
        internal
        override
    {
        uint256 projectId = requestToProject[requestId];

        if (err.length == 0 && response.length > 0) {
            // 1. Decode Production and Revenue from the JS response
            // Your JS source should return: abi.encode(uint256 kwh, uint256 revenueInUsdc)
            (uint256 kwh, uint256 revenueAmount) = abi.decode(response, (uint256, uint256));

            // 2. Update Production Records (for LoanManager checks)
            uint256 monthIndex = block.timestamp / 30 days;
            monthlyProduction[projectId][monthIndex] = kwh;

            // 3. TRIGGER REVENUE FLOW (Mirroring Mock logic)
            // Note: This contract must hold or be sent USDC to distribute
            if (revenueAmount > 0) {
                USDC.approve(address(DISTRIBUTOR), revenueAmount);
                DISTRIBUTOR.depositGridRevenue(projectId, revenueAmount);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        IOracles Implementation
    //////////////////////////////////////////////////////////////*/

    function requestProduction(uint256 projectId, string calldata meterId)
        external
        override
        returns (bytes32 requestId)
    {
        require(msg.sender == loanManager || msg.sender == owner(), "Not authorized");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        string[] memory args = new string[](1);
        args[0] = meterId;
        req.setArgs(args);

        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        requestToProject[requestId] = projectId;
    }

    function getProduction(uint256 projectId, uint256 monthIndex)
        external
        view
        override
        returns (uint256)
    {
        return monthlyProduction[projectId][monthIndex];
    }

    // Boilerplate for Interface
    function getRainyDays(uint256) external pure override returns (uint256) {
        return 0;
    }

    function requestWeatherCheck(uint256, string calldata)
        external
        pure
        override
        returns (bytes32)
    {
        return bytes32(0);
    }

    function triggerHardwareLock(uint256) external pure override {
        revert("IoT only");
    }

    function unlockHardware(uint256) external pure override {
        revert("IoT only");
    }

    function setLoanManager(address _loanManager) external onlyOwner {
        loanManager = _loanManager;
    }

    function setJavascriptSource(string calldata _sourceCode) external onlyOwner {
        sourceCode = _sourceCode;
    }
}
