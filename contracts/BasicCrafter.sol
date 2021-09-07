// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import './ProvablyRareGemV2.sol';

/// @title Basic GEM Crafter
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract BasicGemCrafter is Ownable {
  ProvablyRareGemV2 public immutable GEM;

  mapping(uint => uint) public crafted;

  constructor(ProvablyRareGemV2 _gem) {
    GEM = _gem;
    _gem.create('Turquoise', '#30D5C8', 8**2, 64, 10000, address(this), msg.sender);
    _gem.create('Pearl', '#EAE0C8', 8**3, 32, 10001, address(this), msg.sender);
    _gem.create('Zircon', '#007082', 8**4, 16, 10005, address(this), msg.sender);
    _gem.create('Moonstone', '#A3C6C2', 8**5, 8, 10010, address(this), msg.sender);
    _gem.create('Amber', '#FFBF00', 8**6, 4, 10030, address(this), msg.sender);
    _gem.create('Spinel', '#034B03', 8**7, 2, 10100, address(this), msg.sender);
    _gem.create('White Opal', '#7FFFD4', 8**8, 1, 10300, address(this), msg.sender);
    _gem.create('Violet Garnet', '#872282', 8**9, 1, 11000, address(this), msg.sender);
    _gem.create('Pheonix Feather', '#F26722', 8**10, 1, 20000, address(this), msg.sender);
    _gem.create('Yggdrasil Seed', '#21B54B', 8**11, 1, 50000, address(this), msg.sender);
    _gem.create('Ocean Heart', '#1E88B4', 8**11, 1, 50000, address(this), msg.sender);
    _gem.create("Philosopher's Stone", '#660000', 8**11, 1, 50000, address(this), msg.sender);
  }

  /// @dev Creaes more GEM
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint gemsPerMine,
    uint multiplier
  ) external onlyOwner {
    GEM.create(name, color, difficulty, gemsPerMine, multiplier, address(this), msg.sender);
  }

  /// @dev Called once to start mining for the given kinds.
  function start(uint[] calldata kinds) external onlyOwner {
    for (uint idx = 0; idx < kinds.length; idx++) {
      GEM.updateEntropy(kinds[idx], blockhash(block.number - 1));
    }
  }

  /// @dev Called to stop mining for the given kinds.
  function stop(uint[] calldata kinds) external onlyOwner {
    for (uint idx = 0; idx < kinds.length; idx++) {
      GEM.updateEntropy(kinds[idx], bytes32(0));
    }
  }

  /// @dev Called by gem manager to craft gems. Can't craft more than 10% of supply.
  function craft(uint kind, uint amount) external onlyOwner {
    require(amount != 0, 'zero amount craft');
    crafted[kind] += amount;
    GEM.craft(kind, amount, msg.sender);
    require(crafted[kind] <= GEM.totalSupply(kind) / 10, 'too many crafts');
  }
}
