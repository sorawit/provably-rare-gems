// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/utils/ERC1155Receiver.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/IERC1155.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/ERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

/// @title Wrapped Gem
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract WrappedGem is Initializable, ERC20('', ''), ERC1155Receiver {
  address public gem;
  uint public kind;
  string private _name;
  string private _symbol;
  uint private lock;

  modifier nonReentrant() {
    require(lock == 1, '!lock');
    lock = 2;
    _;
    lock = 1;
  }

  /// @dev Initializes the contract. Can only be called once at deployment.
  function initialize(
    address _gem,
    uint _kind,
    string calldata __name,
    string calldata __symbol
  ) external initializer {
    lock = 1;
    gem = _gem;
    kind = _kind;
    _name = __name;
    _symbol = __symbol;
  }

  /// @dev Returns the token name. Override to work with upgradable pattern.
  function name() public view override returns (string memory) {
    return _name;
  }

  /// @dev Returns the token symbol. Override to work with upgradable pattern.
  function symbol() public view override returns (string memory) {
    return _symbol;
  }

  /// @dev Burns wrapped GEMs to obtain back the original GEMs.
  function redeem(uint value) external nonReentrant {
    require(value > 0, 'bad value');
    _burn(msg.sender, value * 10**18);
    IERC1155(gem).safeTransferFrom(address(this), msg.sender, kind, value, '');
  }

  /// @dev On receiving the GEMs, this contract mints wrapped GEMs for the sender.
  function onERC1155Received(
    address operator,
    address from,
    uint id,
    uint value,
    bytes calldata data
  ) external override returns (bytes4) {
    require(msg.sender == gem, 'not gem token');
    require(id == kind, 'bad kind');
    require(value > 0, 'bad value');
    require(data.length == 0, 'bad data');
    require(from == operator, 'from not operator');
    _mint(from, value * 10**18);
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint[] calldata ids,
    uint[] calldata values,
    bytes calldata data
  ) external override returns (bytes4) {
    revert('not supported');
  }
}
