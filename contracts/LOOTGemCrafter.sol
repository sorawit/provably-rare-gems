// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';
import './ProvablyRareGem.sol';

contract LOOTGemCrafter is Ownable, ReentrancyGuard {
  IERC721 public immutable NFT;
  ProvablyRareGem public immutable GEM;
  uint public immutable FST_KIND;
  uint public immutable LST_KIND;

  event Start(bytes32 hashseed);
  event Craft(uint indexed kind, uint amount);
  event Claim(uint indexed id, address indexed claimer);

  bytes32 public hashseed;
  mapping(uint => uint) public crafted;
  mapping(uint => bool) public claimed;

  constructor(IERC721 _nft, ProvablyRareGem _gem) {
    NFT = _nft;
    GEM = _gem;
    FST_KIND = _gem.create('Amethyst', '#9966CC', 8**2, 64, 10000, address(this), msg.sender);
    _gem.create('Topaz', '#FFC87C', 8**3, 32, 10001, address(this), msg.sender);
    _gem.create('Opal', '#A8C3BC', 8**4, 16, 10005, address(this), msg.sender);
    _gem.create('Sapphire', '#0F52BA', 8**5, 8, 10010, address(this), msg.sender);
    _gem.create('Ruby', '#E0115F', 8**6, 4, 10030, address(this), msg.sender);
    _gem.create('Emerald', '#50C878', 8**7, 2, 10100, address(this), msg.sender);
    _gem.create('Jadeite', '#00A36C', 8**8, 1, 10300, address(this), msg.sender);
    _gem.create('Pink Diamond', '#FC74E4', 8**9, 1, 11000, address(this), msg.sender);
    _gem.create('Blue Diamond', '#348CFC', 8**10, 1, 20000, address(this), msg.sender);
    LST_KIND = _gem.create('Red Diamond', '#BC1C2C', 8**11, 1, 50000, address(this), msg.sender);
  }

  /// @dev Called once to start the claim and generate hash seed.
  function start() external onlyOwner {
    require(hashseed == bytes32(0), 'already started');
    hashseed = blockhash(block.number - 1);
    for (uint kind = FST_KIND; kind <= LST_KIND; kind++) {
      GEM.updateEntropy(kind, hashseed);
    }
  }

  /// @dev Called by gem manager to craft gems. Can't craft more than 10% of supply.
  function craft(uint kind, uint amount) external nonReentrant onlyOwner {
    require(amount != 0, 'zero amount craft');
    crafted[kind] += amount;
    GEM.craft(kind, amount, msg.sender);
    emit Craft(kind, amount);
    require(crafted[kind] <= GEM.totalSupply(kind) / 10, 'too many crafts');
  }

  /// @dev Returns the list of initial GEM distribution for the given NFT ID.
  function airdrop(uint id) public view returns (uint[4] memory kinds) {
    require(hashseed != bytes32(0), 'not yet started');
    uint[10] memory chances = [uint(1), 1, 3, 6, 10, 20, 30, 100, 300, 1000];
    assert(LST_KIND - FST_KIND + 1 == 10);
    uint count = 0;
    for (uint idx = 0; idx < 4; idx++) {
      kinds[idx] = FST_KIND;
    }
    for (uint kind = 9; kind > 0; kind--) {
      uint seed = uint(keccak256(abi.encodePacked(hashseed, kind, id)));
      if (seed % chances[kind] == 0) {
        kinds[count++] = kind;
      }
      if (count == 4) break;
    }
  }

  /// @dev Called by NFT owners to get a welcome pack of gems. Each NFT ID can claim once.
  function claim(uint id) external nonReentrant {
    require(msg.sender == NFT.ownerOf(id), 'not nft owner');
    require(!claimed[id], 'already claimed');
    claimed[id] = true;
    uint[4] memory kinds = airdrop(id);
    for (uint idx = 0; idx < 4; idx++) {
      GEM.craft(FST_KIND + kinds[idx], 0, msg.sender);
    }
    emit Claim(id, msg.sender);
  }
}
