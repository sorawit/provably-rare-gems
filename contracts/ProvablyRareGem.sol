// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';

import './Base64.sol';

/// @title Proably Rare Gems
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareGem is ERC1155Supply, ReentrancyGuard {
  IERC721 public immutable LOOT;
  uint public immutable START_AFTER;

  event Create(uint indexed kind);
  event Mine(address indexed miner, uint indexed kind);
  event Claim(uint indexed lootId, address indexed claimer);

  struct Gem {
    string name; // Gem name
    string color; // Gem color
    bool exists; // True if exist, False otherwise
    uint difficulty; // Current difficulity level. Must be non decreasing
    uint crafted; // Amount of gems crafted by the manager
    uint gemsPerMine; // Amount of gems to distribute per mine
    uint multiplier; // Difficulty multiplier times 1e4. Must be between 1e4 and 1e10
    uint craftCap; // Allocation ratio to gem manager. Must be between 0 and 1e4
    address manager; // Current gem manager
    address pendingManager; // Pending gem manager to be transferred to
  }

  mapping(uint => Gem) public gems;
  mapping(address => uint) public nonce;
  mapping(uint => bool) public claimed;
  bytes32 public hashseed;
  uint public createNonce;

  constructor(address _loot, uint _startAfter) ERC1155('n/a') {
    START_AFTER = _startAfter;
    LOOT = IERC721(_loot);
    address zero = address(0);
    gems[0] = Gem('Amethyst', '#9966CC', true, 8**2, 0, 64, 10000, 1000, msg.sender, zero);
    gems[1] = Gem('Topaz', '#FFC87C', true, 8**3, 0, 32, 10001, 1000, msg.sender, zero);
    gems[2] = Gem('Opal', '#A8C3BC', true, 8**4, 0, 16, 10005, 1000, msg.sender, zero);
    gems[3] = Gem('Sapphire', '#0F52BA', true, 8**5, 0, 8, 10010, 1000, msg.sender, zero);
    gems[4] = Gem('Ruby', '#E0115F', true, 8**6, 0, 4, 10030, 1000, msg.sender, zero);
    gems[5] = Gem('Emerald', '#50C878', true, 8**7, 0, 2, 10100, 1000, msg.sender, zero);
    gems[6] = Gem('Jadeite', '#00A36C', true, 8**8, 0, 1, 10300, 1000, msg.sender, zero);
    gems[7] = Gem('Pink Diamond', '#FC74E4', true, 8**9, 0, 1, 11000, 1000, msg.sender, zero);
    gems[8] = Gem('Blue Diamond', '#348CFC', true, 8**10, 0, 1, 20000, 1000, msg.sender, zero);
    gems[9] = Gem('Red Diamond', '#BC1C2C', true, 8**11, 0, 1, 50000, 1000, msg.sender, zero);
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

  /// @dev Called by anyone to record block hash, allow gem claims, and start the mining.
  function start() external {
    require(block.timestamp >= START_AFTER, 'wait a bit');
    require(hashseed == bytes32(0), 'already started');
    hashseed = blockhash(block.number - 1);
  }

  /// @dev Mines new gemstones. Puts kind you want to mine + your salt and tests your luck!
  function mine(uint kind, uint salt) external nonReentrant {
    uint val = luck(kind, salt);
    nonce[msg.sender]++;
    require(gems[kind].exists, 'gem kind not exist');
    uint diff = gems[kind].difficulty;
    require(val <= type(uint).max / diff, 'salt not good enough');
    gems[kind].difficulty = (diff * gems[kind].multiplier) / 10000 + 1;
    _mint(msg.sender, kind, gems[kind].gemsPerMine, '');
  }

  /// @dev Creates a new gem type. The manager can craft a portion of gems + can premine
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint multiplier,
    uint gemsPerMine,
    uint craftCap,
    uint premine
  ) external nonReentrant {
    require(hashseed != bytes32(0), 'not yet started');
    require(difficulty > 0 && difficulty <= 2**64, 'bad difficulty');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(gemsPerMine > 0 && gemsPerMine <= 1e6, 'bad gems per mine');
    require(craftCap < 1e4, 'bad craft cap');
    require(premine <= 1e9, 'bad premine');
    uint kind = uint(keccak256(abi.encodePacked(block.chainid, address(this), createNonce++)));
    require(!gems[kind].exists, 'gem kind already exists');
    gems[kind] = Gem({
      name: name,
      color: color,
      exists: true,
      difficulty: difficulty,
      crafted: 0,
      gemsPerMine: gemsPerMine,
      multiplier: multiplier,
      craftCap: craftCap,
      manager: msg.sender,
      pendingManager: address(0)
    });
    emit Create(kind);
    _mint(msg.sender, kind, premine, '');
  }

  /// @dev Transfers management ownership for the given gem kinds to another address.
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

  /// @dev Called by LOOT owners to get a welcome pack of gems. Each loot ID can claim once.
  function claim(uint lootId) external nonReentrant {
    require(msg.sender == LOOT.ownerOf(lootId), 'not loot owner');
    require(!claimed[lootId], 'already claimed');
    claimed[lootId] = true;
    uint[4] memory kinds = airdrop(lootId);
    for (uint idx = 0; idx < 4; idx++) {
      _mint(msg.sender, kinds[idx], gems[kinds[idx]].gemsPerMine, '');
    }
    emit Claim(lootId, msg.sender);
  }

  /// @dev Returns the list of initial GEM distribution for the given loot ID.
  function airdrop(uint lootId) public view returns (uint[4] memory kinds) {
    require(hashseed != bytes32(0), 'not yet started');
    uint count = 0;
    for (uint kind = 9; kind > 0; kind--) {
      uint seed = uint(keccak256(abi.encodePacked(hashseed, kind, lootId)));
      uint mod = [1, 1, 3, 6, 10, 20, 30, 100, 300, 1000][kind];
      if (seed % mod == 0) {
        kinds[count++] = kind;
      }
      if (count == 4) break;
    }
  }

  /// @dev Called by gem manager to craft gems. Can't craft more than supply*craftCap/10000.
  function craft(uint kind, uint amount) external nonReentrant {
    Gem storage gem = gems[kind];
    require(gem.exists, 'gem kind not exist');
    require(gem.manager == msg.sender, 'not gem manager');
    gem.crafted += amount;
    _mint(msg.sender, kind, amount, '');
    require(gem.crafted <= (totalSupply(kind) * gem.craftCap) / 10000, 'too many crafts');
  }

  /// @dev Returns your luck given salt and gem kind. The smaller the value, the more chance to succeed.
  function luck(uint kind, uint salt) public view returns (uint) {
    require(hashseed != bytes32(0), 'not yet started');
    bytes memory data = abi.encodePacked(
      block.chainid,
      hashseed,
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
      '"Provably Rare Gems", ',
      '"image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(output)),
      '}'
    ))));
    return string(abi.encodePacked('data:application/json;base64,', json));
  }
}
