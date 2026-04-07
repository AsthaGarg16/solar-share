// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHostReputation {
  struct ReputationScore {
    uint256 score;
    uint256 projectsCreated;
    uint256 projectsCompleted;
    uint256 projectsDefaulted;
    uint256 totalSlashed;
    bool exists;
  }

  function mintSBT(address host) external returns (uint256 tokenId);

  function slashScore(address host, uint256 penaltyAmount) external;

  function getScore(address host) external view returns (uint256 score);

  function incrementProjectsCompleted(address host) external;

  function incrementProjectsCreated(address host) external;

  function getReputationDetails(address host) external view returns (ReputationScore memory);
}
