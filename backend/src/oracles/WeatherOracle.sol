// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracles } from "../interfaces/IOracles.sol";

contract WeatherOracle is FunctionsClient, Ownable, IOracles {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public donId;
    uint64 public subscriptionId;
    string public sourceCode;
    address public maintenanceDao;

    // projectId => count of rainy/low-sun days in the last billing cycle
    mapping(uint256 => uint256) public projectRainyDays;
    mapping(bytes32 => uint256) public requestIdToProject;

    event WeatherUpdated(uint256 indexed projectId, uint256 rainyDays);

    constructor(address router, bytes32 _donId, uint64 _subscriptionId)
        FunctionsClient(router)
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    function setMaintenanceDao(address _dao) external onlyOwner {
        maintenanceDao = _dao;
    }

    function setSource(string calldata _source) external onlyOwner {
        sourceCode = _source;
    }

    /*//////////////////////////////////////////////////////////////
                        IOracles Implementation
    //////////////////////////////////////////////////////////////*/

    function requestWeatherCheck(uint256 projectId, string calldata zipCode)
        external
        override
        returns (bytes32 requestId)
    {
        require(msg.sender == maintenanceDao || msg.sender == owner(), "Not authorized");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);

        string[] memory args = new string[](1);
        args[0] = zipCode;
        req.setArgs(args);

        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, 300000, donId);
        requestIdToProject[requestId] = projectId;
    }

    function getRainyDays(uint256 projectId) external view override returns (uint256) {
        return projectRainyDays[projectId];
    }

    function mockSetRainyDays(uint256 projectId, uint256 rainyDays) external {
        projectRainyDays[projectId] = rainyDays;
        emit WeatherUpdated(projectId, rainyDays);
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK
    //////////////////////////////////////////////////////////////*/

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err)
        internal
        override
    {
        uint256 projectId = requestIdToProject[requestId];

        if (err.length == 0 && response.length > 0) {
            uint256 rainyDays = abi.decode(response, (uint256));
            projectRainyDays[projectId] = rainyDays;
            emit WeatherUpdated(projectId, rainyDays);
        }
    }

    // Boilerplate to satisfy IOracles interface
    function requestProduction(uint256, string calldata) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function getProduction(uint256, uint256) external pure override returns (uint256) {
        return 0;
    }

    function triggerHardwareLock(uint256) external pure override {
        revert();
    }

    function unlockHardware(uint256) external pure override {
        revert();
    }
}
