// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IIoTSolarOracle} from "../interfaces/oracle-interfaces/IIoTSolarOracle.sol";

/// @title IoT Solar Oracle (Killswitch)
/// @notice Uses Chainlink Functions to trigger external solar hardware APIs
contract IoTSolarOracle is FunctionsClient, Ownable, IIoTSolarOracle {
    using FunctionsRequest for FunctionsRequest.Request;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    // Chainlink Functions configuration
    bytes32 public donId; 
    uint64 public subscriptionId; 
    string public sourceCode; 

    // Access control: Only the LoanManager can trigger the killswitch
    address public loanManager;

    // Mapping to track which request belongs to which project
    mapping(bytes32 => uint256) public requestToProject;
    
    // Track if a project's killswitch has been successfully triggered
    mapping(uint256 => bool) public killswitchStatus;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event KillswitchTriggered(uint256 indexed projectId, bytes32 indexed requestId);
    event KillswitchConfirmed(uint256 indexed projectId, bytes response);
    event KillswitchFailed(uint256 indexed projectId, bytes err);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(address router, bytes32 _donId, uint64 _subscriptionId) 
        FunctionsClient(router) 
        Ownable(msg.sender) 
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN SETTERS
    //////////////////////////////////////////////////////////////*/

    function setLoanManager(address _loanManager) external onlyOwner {
        loanManager = _loanManager;
    }

    function setJavascriptSource(string memory _sourceCode) external onlyOwner {
        sourceCode = _sourceCode;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by the LoanManager when a default is declared
    function triggerKillswitch(uint256 projectId, string memory hardwareApiId) 
        external 
        override 
        returns (bytes32 requestId) 
    {
        require(msg.sender == loanManager, "Only LoanManager can trigger");
        require(!killswitchStatus[projectId], "Killswitch already active");

        // 1. Initialize the request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(sourceCode);

        // 2. Pass the specific hardware ID (e.g., inverter serial number) to the JS code
        string[] memory args = new string[](1);
        args[0] = hardwareApiId; 
        req.setArgs(args);

        // 3. Send the request to the Chainlink Network
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            300000, // Gas limit for the callback
            donId
        );

        // Store the mapping so we know which project this request was for
        requestToProject[requestId] = projectId;

        emit KillswitchTriggered(projectId, requestId);
    }

    /// @notice View function to check if a project's system is locked
    function isKillswitchActive(uint256 projectId) external view override returns (bool) {
        return killswitchStatus[projectId];
    }

    /*//////////////////////////////////////////////////////////////
                           CHAINLINK CALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice Chainlink nodes call this function with the result of the API call
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        uint256 projectId = requestToProject[requestId];

        if (err.length != 0) {
            emit KillswitchFailed(projectId, err);
            // In a production system, you might implement retry logic here
        } else {
            // Update the state to reflect that the hardware is now locked to 100% export
            killswitchStatus[projectId] = true;
            emit KillswitchConfirmed(projectId, response);
        }
    }
}