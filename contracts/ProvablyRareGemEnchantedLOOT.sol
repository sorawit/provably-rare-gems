pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/ERC721.sol';
import './LOOTGemCrafterV2.sol';

/// @title Provably Rare Gem Enchanted LOOT
/// @author AlphaFinanceLab
contract ProvablyRareGemEnchantedLOOT is ERC721('Provably Rare Gem Enchanted LOOT', 'ELOOT') {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event Enchant(address indexed nftId, uint[] gemIds, uint[] indices, address indexed owner);
  event Disencahnt(address indexed tokenId, address indexed owner);

  struct EnchantInfo {
    address enchanter;
    uint nftId;
    uint[] gemIds;
    uint[] indices;
  }

  address public owner;
  uint private lock;
  IERC721 public immutable NFT;
  ProvablyRareGemV2 public immutable GEM;
  LOOTGemCrafterV2 public immutable CRAFTER;
  uint public immutable FIRST_KIND;
  uint public constant gemCount = 10;
  uint public constant itemCount = 8;
  uint public enchantCount;

  mapping(uint => EnchantInfo) enchantInfos;

  modifier onlyEOA() {
    require(tx.origin == msg.sender, '!eoa');
    _;
  }

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

  /// @dev Transfers owner.
  /// @param _owner The new owner.
  function transferOwnership(address _owner) external onlyOwner {
    owner = _owner;
    emit OwnershipTransferred(msg.sender, _owner);
  }

  constructor(LOOTGemCrafterV2 _crafter) {
    lock = 1;
    CRAFTER = _crafter;
    NFT = _crafter.NFT();
    GEM = _crafter.GEM();
    FIRST_KIND = _crafter.FIRST_KIND();
    owner = msg.sender;
    emit OwnershipTransferred(address(0), msg.sender);
  }

  function _enchant(
    uint _nftId,
    uint[] calldata _gemIds,
    uint[] calldata _indices
  ) internal {}

  function enchant(
    uint _nftId,
    uint[] calldata _gemIds,
    uint[] calldata _indices
  ) external onlyEOA {
    require(_gemIds.length == _indices.length, '!length');
    require(_gemIds.length > 0, 'no gems');
    NFT.safeTransferFrom(msg.sender, address(this), _nftId);
    bool[] memory sockets = new bool[](itemCount);
    uint[] memory amounts = new uint[](_gemIds.length);
    for (uint i = 0; i < _gemIds.length; i++) {
      require(!sockets[_indices[i]], 'already enchanted');
      sockets[_indices[i]] = true;
      amounts[i] = 1;
    }
    GEM.safeBatchTransferFrom(msg.sender, address(this), _gemIds, amounts, '');

    enchantInfos[enchantCount] = EnchantInfo({
      enchanter: msg.sender,
      nftId: _nftId,
      gemIds: _gemIds,
      indices: _indices
    });

    _mint(msg.sender, enchantCount++);
  }

  function disenchant(uint _tokenId) external onlyEOA {
    EnchantInfo memory info = enchantInfos[_tokenId];
    require(ownerOf(_tokenId) == msg.sender, '!ownerOf');
    _burn(_tokenId);
    NFT.safeTransferFrom(address(this), msg.sender, info.nftId);
    uint[] memory ids = info.gemIds;
    uint[] memory amounts = new uint[](ids.length);
    for (uint i = 0; i < amounts.length; i++) amounts[i] = 1;
    GEM.safeBatchTransferFrom(address(this), msg.sender, ids, amounts, '');
    delete enchantInfos[_tokenId];
  }

  function tokenURI(uint _tokenId) public view override returns (string memory) {
    require(_tokenId < enchantCount, 'enchanted LOOT not exist');
    // TODO
  }
}
