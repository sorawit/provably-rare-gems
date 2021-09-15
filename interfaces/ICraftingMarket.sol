// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface ICraftingMarket {
  function list(uint, uint) external;

  function unlist(uint) external;

  function buy(uint) external;
}
