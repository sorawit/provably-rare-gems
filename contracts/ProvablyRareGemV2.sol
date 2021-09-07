// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

import './Base64.sol';
import './Strings.sol';

/// @title Provably Rare Gems
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareGemV2 is Initializable, ERC1155Supply {
  event Create(uint indexed kind);
  event Mine(address indexed miner, uint indexed kind);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  string public name;

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

  uint private lock;
  address public owner;
  mapping(uint => Gem) public gems;
  mapping(address => uint) public nonce;
  uint public gemCount;

  constructor() ERC1155('GEM') {}

  modifier nonReentrant() {
    require(lock == 1, '!lock');
    lock = 2;
    _;
    lock = 1;
  }

  modifier onlyOwner() {
    require(owner == msg.sender, '!owner');
    _;
  }

  /// @dev Initializes the contract.
  function initialize() external initializer {
    name = 'Provably Rare Gem';
    lock = 1;
    owner = msg.sender;
    emit OwnershipTransferred(address(0), msg.sender);
  }

  /// @dev Transfers owner.
  /// @param _owner The new owner.
  function transferOwnership(address _owner) external onlyOwner {
    owner = _owner;
    emit OwnershipTransferred(msg.sender, _owner);
  }

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
    string memory gemName,
    string memory color,
    uint difficulty,
    uint gemsPerMine,
    uint multiplier,
    address crafter,
    address manager
  ) internal returns (uint) {
    uint kind = gemCount++;
    gems[kind] = Gem({
      name: gemName,
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
    string memory gemName = string(abi.encodePacked(gems[kind].name, ' #', Strings.toString(kind)));
    string memory color = gems[kind].color;
    string memory output = string(abi.encodePacked(
      '<svg id="Layer_1" x="0px" y="0px" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" width="350" height="400"><rect x="0" y="0" width="1080" height="1080" fill="#1a1a1a"/><svg id="Layer_1" x="350" y="350" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" width="350" height="400"><g transform="translate(0 -25)"><g><polygon class="st0" fill="',
      color,
      '" points="679.25,58.27 400.75,58.27 203.82,255.2 203.82,824.8 400.75,1021.73 679.25,1021.73 876.18,824.8 876.18,255.2"></polygon><g class="st1" opacity="0.3"><path d="M679.25,58.27h-278.5L203.82,255.2v569.6l196.93,196.93h278.5L876.18,824.8V255.2L679.25,58.27z M739.56,709.06 l-116.9,116.9H457.34l-116.9-116.9V370.94l116.9-116.9h165.32l116.9,116.9V709.06z"></path></g><g><g><polygon class="st2" fill="none" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" points="679.25,58.27 400.75,58.27 203.82,255.2 203.82,824.8 400.75,1021.73 679.25,1021.73 876.18,824.8  876.18,255.2"></polygon><polygon fill="',
      color,
      '" class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" points="622.66,254.04 457.34,254.04 340.44,370.94 340.44,709.06 457.34,825.96 622.66,825.96  739.56,709.06 739.56,370.94"></polygon><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="400.75" y1="58.27" x2="457.34" y2="254.04"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="679.25" y1="58.27" x2="622.66" y2="254.04"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="203.82" y1="255.2" x2="340.44" y2="370.94"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="739.56" y1="370.94" x2="876.18" y2="255.2"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="739.56" y1="709.06" x2="876.18" y2="824.8"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="622.66" y1="825.96" x2="679.25" y2="1021.73"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="457.34" y1="825.96" x2="400.75" y2="1021.73"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="340.44" y1="709.06" x2="203.82" y2="824.8"></line></g></g></g></g></svg><text x="50%" y="95%" dominant-baseline="middle" text-anchor="middle" font-size="2.5em" fill="#FFFFFF">',
      gemName,
      '</text></svg>'
    ));
    string memory json = Base64.encode(bytes(string(abi.encodePacked(
      '{ "name": "',
      gemName,
      '", ',
      '"description" : ',
      '"Provably Rare Gem is a permissionless on-chain asset for hardcore collectors to mine and collect. Gems must be mined with off-chain Proof-of-Work. The higher the gem rarity, the more difficult it is to be found. Stats and other functionalities are intentionally omitted for others to interpret.", ',
      '"image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(output)),
      '"}'
    ))));
    return string(abi.encodePacked('data:application/json;base64,', json));
  }
}
