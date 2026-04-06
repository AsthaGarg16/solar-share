// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracles } from "../interfaces/IOracles.sol";
// 1. Import the Strings library
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract IoTSolarOracle is FunctionsClient, Ownable, IOracles {
    using FunctionsRequest for FunctionsRequest.Request;
    // 2. Tell Solidity to use Strings for uint256
    using Strings for uint256;

    bytes32 public donId;
    uint64 public subscriptionId;
    string public sourceCode;
    address public loanManager;

    mapping(uint256 => bool) public killswitchStatus;
    mapping(bytes32 => uint256) public requestIdToProject;

    event KillswitchTriggered(uint256 indexed projectId);

    constructor(address router, bytes32 _donId, uint64 _subscriptionId) 
        FunctionsClient(router) 
        Ownable(msg.sender) 
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    function setLoanManager(address _loanManager) external onlyOwner { loanManager = _loanManager; }
    function setSource(string calldata _source) external onlyOwner { sourceCode = _source; }

    /*//////////////////////////////////////////////////////////////
                        IOracles Implementation
    //////////////////////////////////////////////////////////////*/

    function triggerHardwareLock(uint256 projectId) external override {
        require(msg.sender == loanManager || msg.sender == owner(), "Not authorized");
        
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);
        
        string[] memory args = new string[](1);
        // 3. Replace vm.toString(projectId) with Strings.toString(projectId)
        args[0] = Strings.toString(projectId); 
        req.setArgs(args);

        // Chainlink Functions request
        bytes32 requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        requestIdToProject[requestId] = projectId;
        
        emit KillswitchTriggered(projectId);
    }

    function isKillswitchActive(uint256 projectId) external view returns (bool) {
        return killswitchStatus[projectId];
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK
    //////////////////////////////////////////////////////////////*/

    function fulfillRequest(bytes32 requestId, bytes memory /* response */, bytes memory err) internal override {
        uint256 projectId = requestIdToProject[requestId];
        
        if (err.length == 0) {
            killswitchStatus[projectId] = true;
        }
    }

    function unlockHardware(uint256 projectId) external override { killswitchStatus[projectId] = false; }
    function requestProduction(uint256, string calldata) external pure override returns (bytes32) { return bytes32(0); }
    function getProduction(uint256, uint256) external pure override returns (uint256) { return 0; }
    function getRainyDays(uint256) external pure override returns (uint256) { return 0; }
    function requestWeatherCheck(uint256, string calldata) external pure override returns (bytes32) { return bytes32(0); }
}