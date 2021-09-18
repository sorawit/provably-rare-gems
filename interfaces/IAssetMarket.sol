// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface IAssetMarket {
  function modify(
    uint,
    int,
    uint
  ) external;

  function buy(
    address,
    uint,
    uint,
    uint
  ) external;

  function SUMMONER_ID() external view returns (uint);

  function prices(address) external view returns (uint);

  function amounts(address) external view returns (uint);
}
