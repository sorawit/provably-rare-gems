// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';

import './Base64.sol';

/// @title Proably Rare Gems (for Adventurers)
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareGem is ERC1155Supply, ReentrancyGuard {
  IERC721 public immutable LOOT;

  event Create(uint indexed kind);
  event Mine(address indexed miner, uint indexed kind);
  event Claim(uint indexed lootId, address indexed claimer);

  struct Gem {
    string name; // Gem name
    string color; // Gem color
    bool exists; // True if exist, False otherwise
    uint difficulty; // Current difficulity level. Must be non decreasing
    uint crafted; // Amount of gems crafted by the manager
    uint multiplier; // Difficulty multiplier times 1e4. Must be between 1e4 and 1e10
    uint craftCap; // Allocation to gem manager. Must be between 0 and 1e4
    address manager; // Current gem manager
    address pendingManager; // Pending gem manager to be transferred to
  }

  mapping(uint => Gem) public gems;
  mapping(address => uint) public nonce;
  mapping(uint => bool) public claimed;

  constructor(address _loot) ERC1155('n/a') {
    LOOT = IERC721(_loot);
    gems[0] = Gem('Amethyst', '#9966CC', true, 8**2, 0, 10000, 1000, msg.sender, address(0));
    gems[1] = Gem('Topaz', '#FFC87C', true, 8**3, 0, 10001, 1000, msg.sender, address(0));
    gems[2] = Gem('Opal', '#A8C3BC', true, 8**4, 0, 10005, 1000, msg.sender, address(0));
    gems[3] = Gem('Sapphire', '#0F52BA', true, 8**5, 0, 10010, 1000, msg.sender, address(0));
    gems[4] = Gem('Ruby', '#E0115F', true, 8**6, 0, 10030, 1000, msg.sender, address(0));
    gems[5] = Gem('Emerald', '#50C878', true, 8**7, 0, 10100, 1000, msg.sender, address(0));
    gems[6] = Gem('Jadelite', '#00A36C', true, 8**8, 0, 10300, 1000, msg.sender, address(0));
    gems[7] = Gem('Pink Diamond', '#FC74E4', true, 8**9, 0, 11000, 1000, msg.sender, address(0));
    gems[8] = Gem('Blue Diamond', '#348CFC', true, 8**10, 0, 20000, 1000, msg.sender, address(0));
    gems[9] = Gem('Red Diamond', '#BC1C2C', true, 8**11, 0, 50000, 1000, msg.sender, address(0));
    emit Create(0);
    emit Create(1);
    emit Create(2);
    emit Create(3);
    emit Create(4);
    emit Create(5);
    emit Create(6);
    emit Create(7);
    emit Create(8);
    emit Create(9);
  }

  /// @dev Mines new gemstones. Puts kind you want to mine + your salt and tests your luck!
  function mine(uint kind, uint salt) external nonReentrant {
    uint val = luck(kind, salt);
    nonce[msg.sender]++;
    require(gems[kind].exists, 'gem kind not exist');
    uint diff = gems[kind].difficulty;
    require(val <= type(uint).max / diff, 'salt not good enough');
    gems[kind].difficulty = (diff * gems[kind].multiplier) / 10000 + 1;
    _mint(msg.sender, kind, 1, '');
  }

  /// @dev Creates a new gem type. The manager that can craft a portion of gems + can premine
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint multiplier,
    uint craftCap,
    uint premine
  ) external nonReentrant {
    require(difficulty > 0, 'bad difficulty');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(craftCap < 1e4, 'bad craft cap');
    uint kind = uint(keccak256(abi.encodePacked(block.chainid, address(this), msg.sender, name)));
    require(!gems[kind].exists, 'gem kind already exists');
    gems[kind] = Gem({
      name: name,
      color: color,
      exists: true,
      difficulty: difficulty,
      crafted: 0,
      multiplier: multiplier,
      craftCap: craftCap,
      manager: msg.sender,
      pendingManager: address(0)
    });
    emit Create(kind);
    _mint(msg.sender, kind, premine, '');
  }

  /// @dev Transfer management ownership for the given gem kinds to another address.
  function transferManager(uint[] calldata kinds, address to) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(gems[kind].exists, 'gem kind not exist');
      require(gems[kind].manager == msg.sender, 'not gem manager');
      gems[kind].pendingManager = to;
    }
  }

  /// @dev Accepts management position for the given gem kinds.
  function acceptManager(uint[] calldata kinds) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(gems[kind].exists, 'gem kind not exist');
      require(gems[kind].pendingManager == msg.sender, 'not gem manager');
      gems[kind].pendingManager = address(0);
      gems[kind].manager = msg.sender;
    }
  }

  /// @dev Called by LOOT owners to get welcome back of gems. Each loot ID can claim once.
  function claim(uint lootId) external nonReentrant {
    require(msg.sender == LOOT.ownerOf(lootId), 'not loot owner');
    require(!claimed[lootId], 'already claimed');
    claimed[lootId] = true;
    uint[4] memory kinds = airdrop(lootId);
    for (uint idx = 0; idx < 4; idx++) {
      _mint(msg.sender, kinds[idx], 1, '');
    }
    emit Claim(lootId, msg.sender);
  }

  /// @dev Returns the list of initial GEM distribution for the given loot ID.
  function airdrop(uint lootId) public pure returns (uint[4] memory kinds) {
    uint count = 0;
    for (uint kind = 9; kind > 0; kind--) {
      uint seed = uint(keccak256(abi.encodePacked(kind, lootId)));
      uint mod = [1, 1, 3, 6, 10, 20, 30, 100, 300, 1000][kind];
      if (seed % mod == 0) {
        kinds[count++] = kind;
      }
      if (count == 4) break;
    }
  }

  /// @dev Called gem manager to craft gems. Can't craft more than supply*craftCap/10000.
  function craft(uint kind, uint amount) external nonReentrant {
    Gem storage gem = gems[kind];
    require(gem.exists, 'gem kind not exist');
    require(gem.manager == msg.sender, 'not gem manager');
    gem.crafted += amount;
    _mint(msg.sender, kind, amount, '');
    require(gem.crafted <= (totalSupply(kind) * gem.craftCap) / 10000, 'too many crafts');
  }

  /// @dev Returns your luck given salt. The smaller the value, the better GEMs you will receive.
  function luck(uint kind, uint salt) public view returns (uint) {
    bytes memory data = abi.encodePacked(
      block.chainid,
      address(this),
      msg.sender,
      kind,
      nonce[msg.sender],
      salt
    );
    return uint(keccak256(data));
  }

  // prettier-ignore
  function uri(uint kind) public view override returns (string memory) {
    require(gems[kind].exists, 'gem kind not exist');
    string memory output = string(abi.encodePacked(
        '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: ',
        gems[kind].color,
        '; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="white" /><text x="10" y="20" class="base">',
        gems[kind].name,
        '</text><text x="10" y="40" class="base">',
        '</text></svg>'
    ));
    string memory json = Base64.encode(bytes(string(abi.encodePacked(
      '{ "name": "',
      gems[kind].name,
      '", ',
      '"description" : ',
      '"Provably Rare Gems (for Adventurers)", ',
      '"image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(output)),
      '}'
    ))));
    return string(abi.encodePacked('data:application/json;base64,', json));
  }
}
