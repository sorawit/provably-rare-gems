// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';
import './ProvablyRareGem.sol';

/// @title BLOOT GEM Crafter
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract BLOOTGemCrafter is Ownable, ReentrancyGuard {
  IERC721 public immutable NFT;
  ProvablyRareGem public immutable GEM;
  uint public immutable FIRST_KIND;

  event Start(bytes32 hashseed);
  event Craft(uint indexed kind, uint amount);
  event Claim(uint indexed id, address indexed claimer);

  bytes32 public hashseed;
  mapping(uint => uint) public crafted;
  mapping(uint => bool) public claimed;

  // prettier-ignore
  constructor(IERC721 _nft, ProvablyRareGem _gem) {
    NFT = _nft;
    GEM = _gem;
    FIRST_KIND = _gem.gemCount();
    _gem.create('Violet Useless Rock of ALPHA', '#9966CC', 8**2, 64, 10000, address(this), msg.sender);
    _gem.create('Goldy Pebble of LOOKS RARE', '#FFC87C', 8**3, 32, 10001, address(this), msg.sender);
    _gem.create('Translucent River Rock of HODL', '#A8C3BC', 8**4, 16, 10005, address(this), msg.sender);
    _gem.create('Blue Ice Scrap of UP ONLY', '#0F52BA', 8**5, 8, 10010, address(this), msg.sender);
    _gem.create('Blushing Rock of PROBABLY NOTHING', '#E0115F', 8**6, 4, 10030, address(this), msg.sender);
    _gem.create('Mossy Riverside Pebble of LFG', '#50C878', 8**7, 2, 10100, address(this), msg.sender);
    _gem.create('The Lovely Rock of GOAT', '#FC74E4', 8**8, 1, 10300, address(this), msg.sender);
    _gem.create('#00FF00 of OG', '#00FF00', 8**9, 1, 11000, address(this), msg.sender);
    _gem.create('#0000FF of WAGMI', '#0000FF', 8**10, 1, 20000, address(this), msg.sender);
    _gem.create('#FF0000 of THE MOON', '#FF0000', 8**11, 1, 50000, address(this), msg.sender);
  }

  /// @dev Called once to start the claim and generate hash seed.
  function start() external onlyOwner {
    require(hashseed == bytes32(0), 'already started');
    hashseed = blockhash(block.number - 1);
    for (uint offset = 0; offset < 10; offset++) {
      GEM.updateEntropy(FIRST_KIND + offset, hashseed);
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
    uint count = 0;
    for (uint idx = 0; idx < 4; idx++) {
      kinds[idx] = FIRST_KIND;
    }
    for (uint offset = 9; offset > 0; offset--) {
      uint seed = uint(keccak256(abi.encodePacked(hashseed, offset, id)));
      if (seed % chances[offset] == 0) {
        kinds[count++] = FIRST_KIND + offset;
      }
      if (count == 4) break;
    }
  }

  /// @dev Called by NFT owners to get a welcome pack of gems. Each NFT ID can claim once.
  function claim(uint id) external nonReentrant {
    _claim(id);
  }

  /// @dev Called by NFT owners to get a welcome pack of gems for multiple NFTs.
  function multiClaim(uint[] calldata ids) external nonReentrant {
    for (uint idx = 0; idx < ids.length; idx++) {
      _claim(ids[idx]);
    }
  }

  function _claim(uint id) internal {
    require(msg.sender == NFT.ownerOf(id), 'not nft owner');
    require(!claimed[id], 'already claimed');
    claimed[id] = true;
    uint[4] memory kinds = airdrop(id);
    for (uint idx = 0; idx < 4; idx++) {
      GEM.craft(kinds[idx], 0, msg.sender);
    }
    emit Claim(id, msg.sender);
  }
}
