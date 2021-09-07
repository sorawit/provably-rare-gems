// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/Pausable.sol';
import './ProvablyRareGemV2.sol';

/// @title Basic GEM Crafter
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract BasicGemCrafter is Ownable, Pausable {
  ProvablyRareGemV2 public immutable GEM;
  uint public immutable FIRST_KIND;

  mapping(uint => uint) public crafted;
  uint public craftCap;

  constructor(ProvablyRareGemV2 _gem, uint _craftCap) {
    GEM = _gem;
    FIRST_KIND = _gem.gemCount();
    _gem.create('Amethyst', '#9966CC', 8**2, 64, 10000, address(this), msg.sender);
    _gem.create('Topaz', '#FFC87C', 8**3, 32, 10001, address(this), msg.sender);
    _gem.create('Opal', '#A8C3BC', 8**4, 16, 10005, address(this), msg.sender);
    _gem.create('Sapphire', '#0F52BA', 8**5, 8, 10010, address(this), msg.sender);
    _gem.create('Ruby', '#E0115F', 8**6, 4, 10030, address(this), msg.sender);
    _gem.create('Emerald', '#50C878', 8**7, 2, 10100, address(this), msg.sender);
    _gem.create('Pink Diamond', '#FC74E4', 8**8, 1, 10300, address(this), msg.sender);
    _gem.create('The Dragon Jade', '#00A36C', 8**9, 1, 11000, address(this), msg.sender);
    _gem.create('Azure Skystone', '#348CFC', 8**10, 1, 20000, address(this), msg.sender);
    _gem.create('Scarlet Bloodstone', '#BC1C2C', 8**11, 1, 50000, address(this), msg.sender);
    craftCap = _craftCap;
  }

  /// @dev Pause crafter. Can only be called by owner.
  function pause() external onlyOwner {
    _pause();
  }

  /// @dev Unpause crafter. Can only be called by owner.
  function unpause() external onlyOwner {
    _unpause();
  }

  /// @dev Called once to start mining for the given offset.
  function start(uint offset) external onlyOwner whenNotPaused {
    GEM.updateEntropy(FIRST_KIND + offset, blockhash(block.number - 1));
  }

  /// @dev Called to stop mining for the given offset.
  function stop(uint offset) external onlyOwner whenNotPaused {
    GEM.updateEntropy(FIRST_KIND + offset, bytes32(0));
  }

  /// @dev Called by gem manager to craft gems. Can't craft more than 10% of supply.
  function craft(uint kind, uint amount) external onlyOwner whenNotPaused {
    require(amount != 0, 'zero amount craft');
    crafted[kind] += amount;
    GEM.craft(kind, amount, msg.sender);
    require(crafted[kind] <= GEM.totalSupply(kind) / 10, 'too many crafts');
  }
}
