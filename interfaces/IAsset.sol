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
}
