// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/// @title Basic Governor Module
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract Gov {
  address public governor;
  address public pendingGovernor;
  event SetGovernor(address governor);

  constructor() {
    governor = msg.sender;
    emit SetGovernor(governor);
  }

  modifier gov() {
    require(msg.sender == governor, 'not governor');
    _;
  }

  /// @dev Sets the next governor address, which will become effective once accepted.
  function setPendingGovernor(address _pendingGovernor) external gov {
    pendingGovernor = _pendingGovernor;
  }

  /// @dev Accepts the governor role.
  function acceptGovernor() external {
    require(msg.sender == pendingGovernor, 'not pending governor');
    pendingGovernor = address(0);
    governor = msg.sender;
    emit SetGovernor(msg.sender);
  }
}
