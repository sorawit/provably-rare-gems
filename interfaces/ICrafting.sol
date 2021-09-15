// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

interface ICrafting {
  function items(uint)
    external
    view
    returns (
      uint8,
      uint8,
      uint32,
      uint
    );
}
