// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/math/Math.sol';

import './Base64.sol';
import './Gov.sol';

/// @title Loot's Proably Rare Gems (for Adventurers)
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareGem is ERC1155Supply, ReentrancyGuard, Gov {
  IERC721 constant LOOT = IERC721(0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7);

  event Mine(address indexed minter, uint indexed kind);
  event Claim(uint indexed lootId, address indexed claimer);

  mapping(address => uint) public nonce;
  mapping(uint => bool) public claimed;
  uint[10] public crafted;
  uint[10] public difficulty;

  constructor() ERC1155('n/a') {
    for (uint kind = 0; kind < 10; kind++) {
      difficulty[kind] = 8**kind;
    }
  }

  /// @dev Mines new gemstones. Puts your salt and tests your luck!
  function mine(uint salt) external nonReentrant returns (uint) {
    uint val = luck(salt);
    nonce[msg.sender]++;
    for (uint kind = 9; kind >= 0; kind--) {
      uint diff = difficulty[kind];
      if (val <= type(uint).max / diff) {
        difficulty[kind] = (difficulty[kind] * multiplier(kind)) / 10000;
        for (uint id = 0; id <= kind; id++) {
          _mint(msg.sender, id, 1, '');
        }
        emit Mine(msg.sender, kind);
        return kind;
      }
    }
    assert(false);
  }

  /// @dev Called by LOOT owners to get welcome back of gems. Each loot ID can claim once.
  function claim(uint lootId) external nonReentrant {
    require(msg.sender == LOOT.ownerOf(lootId), 'not loot owner');
    require(claimed[lootId], 'already claimed');
    claimed[lootId] = true;
    for (uint kind = 0; kind < 5; kind++) {
      _mint(msg.sender, kind, 1, '');
    }
    emit Claim(lootId, msg.sender);
  }

  /// @dev Called by DAO governor to craft gems. Can't craft more than ceil[supply/10].
  function craft(uint kind, uint amount) external gov nonReentrant {
    require(kind < 10, 'bad kind');
    crafted[kind] += amount;
    _mint(msg.sender, kind, amount, '');
    require(crafted[kind] <= Math.ceilDiv(totalSupply(kind), 10), 'too many crafts');
  }

  /// @dev Returns name of the given gemstone kind.
  function gem(uint kind) public view returns (string memory) {
    require(kind < 10, 'bad kind');
    return
      [
        'Amethyst',
        'Topaz',
        'Opal',
        'Sapphire',
        'Ruby',
        'Emerald',
        'Jadelite',
        'Pink Diamond',
        'Blue Diamond',
        'Red Diamond'
      ][kind];
  }

  /// @dev Returns HEX color of the given gemstone kind.
  function color(uint kind) public view returns (string memory) {
    require(kind < 10, 'bad kind');
    return
      [
        '#9966CC',
        '#FFC87C',
        '#A8C3BC',
        '#0F52BA',
        '#E0115F',
        '#50C878',
        '#00A36C',
        '#FED0FC',
        '#00A0FF',
        '#C50100'
      ][kind];
  }

  /// @dev Returns the difficulity multiplier once the given gem kind is mined, times 1e4.
  function multiplier(uint kind) public view returns (uint) {
    require(kind < 10, 'bad kind');
    return [10000, 10001, 10005, 10010, 10030, 10100, 10300, 11000, 20000, 50000][kind];
  }

  /// @dev Returns your luck given salt. The smaller the value, the better GEMs you will receive.
  function luck(uint salt) public view returns (uint) {
    bytes memory data = abi.encodePacked(
      block.chainid,
      address(this),
      msg.sender,
      nonce[msg.sender],
      salt
    );
    uint baseLuck = uint(keccak256(data));
    if (LOOT.balanceOf(msg.sender) > 0) {
      return baseLuck / 10; // 10x better luck for LOOT owners
    } else {
      return baseLuck;
    }
  }

  // prettier-ignore
  function uri(uint kind) public view override returns (string memory) {
    string[6] memory parts;
    parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: ';
    parts[1] = color(kind);
    parts[2] = '; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="white" /><text x="10" y="20" class="base">';
    parts[3] = gem(kind);
    parts[4] = '</text><text x="10" y="40" class="base">';
    parts[5] = '</text></svg>';
    string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]));
    string memory json = Base64.encode(bytes(string(abi.encodePacked(
      '{ "name": "',
      gem(kind),
      '", ',
      '"description" : ',
      '"Loot\'s Provably Rare Gems (for Adventurers)", ',
      '"image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(output)),
      '}'
    ))));
    return string(abi.encodePacked('data:application/json;base64,', json));
  }
}
