// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface IRarity {
  function next_summoner() external view returns (uint);

  function summon(uint _class) external;

  function ownerOf(uint) external view returns (address);

  function getApproved(uint) external view returns (address);
}
