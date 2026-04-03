// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Parametric Weather Oracle
/// @notice Uses Chainlink Functions to fetch historical rainfall data for insurance claims
contract WeatherOracle is FunctionsClient, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public donId;
    uint64 public subscriptionId;
    string public sourceCode;
    
    address public maintenanceDAO;

    // Maps a Chainlink Request ID to a Project ID
    mapping(bytes32 => uint256) public requestToProject;
    
    // Stores the latest weather result (e.g., number of rainy days last month)
    mapping(uint256 => uint256) public projectRainyDays;

    event WeatherRequested(uint256 indexed projectId, bytes32 indexed requestId);
    event WeatherUpdated(uint256 indexed projectId, uint256 rainyDays);

    constructor(address router, bytes32 _donId, uint64 _subscriptionId) 
        FunctionsClient(router) 
        Ownable(msg.sender) 
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    function setMaintenanceDAO(address _dao) external onlyOwner {
        maintenanceDAO = _dao;
    }

    function setJavascriptSource(string memory _sourceCode) external onlyOwner {
        sourceCode = _sourceCode;
    }

    /// @notice Called by MaintenanceDAO to check if bad weather caused low revenue
    function requestWeatherCheck(uint256 projectId, string memory zipCode) external returns (bytes32 requestId) {
        require(msg.sender == maintenanceDAO || msg.sender == owner(), "Not authorized");

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);

        // Pass the project's zip code to the JS script
        string[] memory args = new string[](1);
        args[0] = zipCode; 
        req.setArgs(args);

        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            300000, // Gas limit
            donId
        );

        requestToProject[requestId] = projectId;
        emit WeatherRequested(projectId, requestId);
    }

    /// @notice Chainlink nodes return the weather data here
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        uint256 projectId = requestToProject[requestId];

        if (err.length == 0) {
            // Decode the returned bytes into a uint256
            uint256 rainyDays = abi.decode(response, (uint256));
            projectRainyDays[projectId] = rainyDays;
            emit WeatherUpdated(projectId, rainyDays);
        }
    }
    
    /// @notice Read function for the DAO to check the stored weather result
    function getRainyDays(uint256 projectId) external view returns (uint256) {
        return projectRainyDays[projectId];
    }
}