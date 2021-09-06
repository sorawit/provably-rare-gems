// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/security/ReentrancyGuard.sol';

import './Base64.sol';

/// @title Provably Rare Gems
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareGem is ERC1155Supply, ReentrancyGuard {
  event Create(uint indexed kind);
  event Mine(address indexed miner, uint indexed kind);

  struct Gem {
    string name; // Gem name
    string color; // Gem color
    bytes32 entropy; // Additional mining entropy. bytes32(0) means can't mine.
    uint difficulty; // Current difficulity level. Must be non decreasing
    uint gemsPerMine; // Amount of gems to distribute per mine
    uint multiplier; // Difficulty multiplier times 1e4. Must be between 1e4 and 1e10
    address crafter; // Address that can craft gems
    address manager; // Current gem manager
    address pendingManager; // Pending gem manager to be transferred to
  }

  mapping(uint => Gem) public gems;
  mapping(address => uint) public nonce;
  uint public gemCount;

  constructor() ERC1155('GEM') {}

  /// @dev Creates a new gem type. The manager can craft a portion of gems + can premine
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint gemsPerMine,
    uint multiplier,
    address crafter,
    address manager
  ) external returns (uint) {
    require(difficulty > 0 && difficulty <= 2**128, 'bad difficulty');
    require(gemsPerMine > 0 && gemsPerMine <= 1e6, 'bad gems per mine');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(manager != address(0), 'bad manager');
    return _create(name, color, difficulty, gemsPerMine, multiplier, crafter, manager);
  }

  /// @dev Mines new gemstones. Puts kind you want to mine + your salt and tests your luck!
  function mine(uint kind, uint salt) external nonReentrant {
    uint val = luck(kind, salt);
    nonce[msg.sender]++;
    require(kind < gemCount, 'gem kind not exist');
    uint diff = gems[kind].difficulty;
    require(val <= type(uint).max / diff, 'salt not good enough');
    gems[kind].difficulty = (diff * gems[kind].multiplier) / 10000 + 1;
    _mint(msg.sender, kind, gems[kind].gemsPerMine, '');
  }

  /// @dev Updates gem mining entropy. Can be called by gem manager or crafter.
  function updateEntropy(uint kind, bytes32 entropy) external {
    require(kind < gemCount, 'gem kind not exist');
    require(gems[kind].manager == msg.sender || gems[kind].crafter == msg.sender, 'unauthorized');
    gems[kind].entropy = entropy;
  }

  /// @dev Updates gem metadata info. Must only be called by the gem manager.
  function updateGemInfo(
    uint kind,
    string calldata name,
    string calldata color
  ) external {
    require(kind < gemCount, 'gem kind not exist');
    require(gems[kind].manager == msg.sender, 'not gem manager');
    gems[kind].name = name;
    gems[kind].color = color;
  }

  /// @dev Updates gem mining information. Must only be called by the gem manager.
  function updateMiningData(
    uint kind,
    uint difficulty,
    uint multiplier,
    uint gemsPerMine
  ) external {
    require(kind < gemCount, 'gem kind not exist');
    require(gems[kind].manager == msg.sender, 'not gem manager');
    require(difficulty > 0 && difficulty <= 2**128, 'bad difficulty');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(gemsPerMine > 0 && gemsPerMine <= 1e6, 'bad gems per mine');
    gems[kind].difficulty = difficulty;
    gems[kind].multiplier = multiplier;
    gems[kind].gemsPerMine = gemsPerMine;
  }

  /// @dev Renounce management ownership for the given gem kinds.
  function renounceManager(uint[] calldata kinds) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < gemCount, 'gem kind not exist');
      require(gems[kind].manager == msg.sender, 'not gem manager');
      gems[kind].manager = address(0);
      gems[kind].pendingManager = address(0);
    }
  }

  /// @dev Updates gem crafter. Must only be called by the gem manager.
  function updateCrafter(uint[] calldata kinds, address crafter) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < gemCount, 'gem kind not exist');
      require(gems[kind].manager == msg.sender, 'not gem manager');
      gems[kind].crafter = crafter;
    }
  }

  /// @dev Transfers management ownership for the given gem kinds to another address.
  function transferManager(uint[] calldata kinds, address to) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < gemCount, 'gem kind not exist');
      require(gems[kind].manager == msg.sender, 'not gem manager');
      gems[kind].pendingManager = to;
    }
  }

  /// @dev Accepts management position for the given gem kinds.
  function acceptManager(uint[] calldata kinds) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < gemCount, 'gem kind not exist');
      require(gems[kind].pendingManager == msg.sender, 'not pending manager');
      gems[kind].pendingManager = address(0);
      gems[kind].manager = msg.sender;
    }
  }

  /// @dev Mints gems by crafter. Hopefully, crafter is a good guy. Craft gemsPerMine if amount = 0.
  function craft(
    uint kind,
    uint amount,
    address to
  ) external nonReentrant {
    require(kind < gemCount, 'gem kind not exist');
    require(gems[kind].crafter == msg.sender, 'not gem crafter');
    uint realAmount = amount == 0 ? gems[kind].gemsPerMine : amount;
    _mint(to, kind, realAmount, '');
  }

  /// @dev Returns your luck given salt and gem kind. The smaller the value, the more success chance.
  function luck(uint kind, uint salt) public view returns (uint) {
    require(kind < gemCount, 'gem kind not exist');
    bytes32 entropy = gems[kind].entropy;
    require(entropy != bytes32(0), 'no entropy');
    bytes memory data = abi.encodePacked(
      block.chainid,
      entropy,
      address(this),
      msg.sender,
      kind,
      nonce[msg.sender],
      salt
    );
    return uint(keccak256(data));
  }

  /// @dev Internal function for creating a new gem kind
  function _create(
    string memory name,
    string memory color,
    uint difficulty,
    uint gemsPerMine,
    uint multiplier,
    address crafter,
    address manager
  ) internal returns (uint) {
    uint kind = gemCount++;
    gems[kind] = Gem({
      name: name,
      color: color,
      entropy: bytes32(0),
      difficulty: difficulty,
      gemsPerMine: gemsPerMine,
      multiplier: multiplier,
      crafter: crafter,
      manager: manager,
      pendingManager: address(0)
    });
    emit Create(kind);
    return kind;
  }

  // prettier-ignore
  function uri(uint kind) public view override returns (string memory) {
    require(kind < gemCount, 'gem kind not exist');
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
