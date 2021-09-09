// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

/// @dev Summoner market proxy
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract SummonerMarketProxy is TransparentUpgradeableProxy {
  constructor(
    address _logic,
    address admin_,
    bytes memory _data
  ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {}
}
