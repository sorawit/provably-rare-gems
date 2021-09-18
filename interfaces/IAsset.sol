// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface IAsset {
  function transferFrom(
    uint,
    uint,
    uint,
    uint
  ) external returns (bool);

  function transfer(
    uint,
    uint,
    uint
  ) external returns (bool);

  function balanceOf(uint) external view returns (uint);

  function ownerOf(uint) external view returns (address);

  function approve(
    uint,
    uint,
    uint
  ) external returns (bool);
}
