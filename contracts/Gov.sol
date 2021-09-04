// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract Gov {
  address public governor;
  address public pendingGovernor;

  constructor() {
    governor = msg.sender;
  }

  modifier gov() {
    require(msg.sender == governor, 'not governor');
    _;
  }

  function setPendingGovernor(address _pendingGovernor) external gov {
    pendingGovernor = _pendingGovernor;
  }

  function acceptGovernor() external {
    require(msg.sender == pendingGovernor, 'not pending governor');
    pendingGovernor = address(0);
    governor = msg.sender;
  }
}
