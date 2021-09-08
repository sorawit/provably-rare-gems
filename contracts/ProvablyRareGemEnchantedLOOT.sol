pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/ERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/IERC1155.sol';
import './ProvablyRareGemV2.sol';
import '../interfaces/ILoot.sol';

/// @title Provably Rare Gem Enchanted LOOT
/// @author AlphaFinanceLab
contract ProvablyRareGemEnchantedLOOT is
  ERC721('Provably Rare Gem Enchanted LOOT', 'ELOOT'),
  IERC1155Receiver,
  IERC721Receiver
{
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event Enchant(uint indexed nftId, uint[] gemIds, uint[] indices, address indexed owner);
  event Disenchant(uint indexed tokenId, address indexed owner);

  struct EnchantInfo {
    uint nftId;
    uint[] gemIds;
    uint[] indices;
  }

  address public owner;
  uint private lock;
  IERC721 public immutable NFT;
  ProvablyRareGemV2 public immutable GEM;
  uint public constant FIRST_KIND = 0;
  uint public enchantCount;
  string[10] private gemShortNames = [
    '[Amethyst] ',
    '[Topaz] ',
    '[Opal] ',
    '[Sapphire] ',
    '[Ruby] ',
    '[Emerald] ',
    '[Pink] ',
    '[Jade] ',
    '[Azure] ',
    '[Scarlet] '
  ];
  string[10] private colorCodes;
  bool private isEnchanting;

  mapping(uint => EnchantInfo) enchantInfos;

  modifier isEnchant() {
    isEnchanting = true;
    _;
    isEnchanting = false;
  }

  modifier inEnchant() {
    require(isEnchanting, '!enchanting');
    _;
  }

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

  constructor(IERC721 _nft, ProvablyRareGemV2 _gem) {
    lock = 1;
    NFT = _nft;
    GEM = _gem;
    owner = msg.sender;
    for (uint i = 0; i < 10; i++) {
      (, colorCodes[i], , , , , , , ) = _gem.gems(FIRST_KIND + i);
    }
    emit OwnershipTransferred(address(0), msg.sender);
  }

  function enchant(
    uint _nftId,
    uint[] calldata _gemIds,
    uint[] calldata _indices
  ) external nonReentrant onlyEOA isEnchant {
    require(_gemIds.length == _indices.length, '!length');
    require(_gemIds.length > 0, 'no gems');
    NFT.safeTransferFrom(msg.sender, address(this), _nftId);
    bool[] memory sockets = new bool[](8);
    uint[] memory amounts = new uint[](_gemIds.length);
    for (uint i = 0; i < _gemIds.length; i++) {
      require(!sockets[_indices[i]], 'already enchanted');
      sockets[_indices[i]] = true;
      amounts[i] = 1;
    }
    GEM.safeBatchTransferFrom(msg.sender, address(this), _gemIds, amounts, '');

    enchantInfos[enchantCount] = EnchantInfo({nftId: _nftId, gemIds: _gemIds, indices: _indices});

    _mint(msg.sender, enchantCount++);
    emit Enchant(_nftId, _gemIds, _indices, msg.sender);
  }

  function disenchant(uint _tokenId) external nonReentrant onlyEOA {
    require(ownerOf(_tokenId) == msg.sender, '!ownerOf');
    _burn(_tokenId);

    EnchantInfo memory info = enchantInfos[_tokenId];
    NFT.safeTransferFrom(address(this), msg.sender, info.nftId);
    uint[] memory ids = info.gemIds;
    uint[] memory amounts = new uint[](ids.length);
    for (uint i = 0; i < amounts.length; i++) amounts[i] = 1;
    GEM.safeBatchTransferFrom(address(this), msg.sender, ids, amounts, '');

    delete enchantInfos[_tokenId];
    emit Disenchant(_tokenId, msg.sender);
  }

  function tokenURI(uint _tokenId) public view override returns (string memory) {
    require(_tokenId < enchantCount, 'enchanted LOOT not exist');
    EnchantInfo memory info = enchantInfos[_tokenId];
    require(info.gemIds.length != 0, 'token id no longer exist');
    uint nftId = info.nftId;

    string[8] memory enchantings;
    string[8] memory colors;
    for (uint i = 0; i < info.gemIds.length; i++) {
      enchantings[info.indices[i]] = gemShortNames[info.gemIds[i] - FIRST_KIND];
      colors[info.indices[i]] = colorCodes[info.gemIds[i] - FIRST_KIND];
    }

    string[8] memory colorParts;
    for (uint i = 0; i < 8; i++) {
      if (bytes(enchantings[i]).length > 0) {
        colorParts[i] = string(
          abi.encodePacked('<tspan fill="', colors[i], '">', enchantings[i], '</tspan>')
        );
      }
    }

    string[17] memory parts;
    parts[
      0
    ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

    parts[1] = ILoot(address(NFT)).getWeapon(nftId);

    parts[2] = '</text><text x="10" y="40" class="base">';

    parts[3] = ILoot(address(NFT)).getChest(nftId);

    parts[4] = '</text><text x="10" y="60" class="base">';

    parts[5] = ILoot(address(NFT)).getHead(nftId);

    parts[6] = '</text><text x="10" y="80" class="base">';

    parts[7] = ILoot(address(NFT)).getWaist(nftId);

    parts[8] = '</text><text x="10" y="100" class="base">';

    parts[9] = ILoot(address(NFT)).getFoot(nftId);

    parts[10] = '</text><text x="10" y="120" class="base">';

    parts[11] = ILoot(address(NFT)).getHand(nftId);

    parts[12] = '</text><text x="10" y="140" class="base">';

    parts[13] = ILoot(address(NFT)).getNeck(nftId);

    parts[14] = '</text><text x="10" y="160" class="base">';

    parts[15] = ILoot(address(NFT)).getRing(nftId);

    parts[16] = '</text></svg>';

    string memory output = string(
      abi.encodePacked(
        parts[0],
        colorParts[0],
        parts[1],
        parts[2],
        colorParts[1],
        parts[3],
        parts[4],
        colorParts[2]
      )
    );
    output = string(
      abi.encodePacked(output, parts[5], parts[6], colorParts[3], parts[7], parts[8], colorParts[4])
    );

    output = string(
      abi.encodePacked(output, parts[9], parts[10], colorParts[5], parts[11], parts[12])
    );

    output = string(
      abi.encodePacked(
        output,
        colorParts[6],
        parts[13],
        parts[14],
        colorParts[7],
        parts[15],
        parts[16]
      )
    );

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "Bag #',
            toString(_tokenId),
            '", "description": "Enchanted Loot is an enchanted gear for hardcore adventurer, a combination of Provably Rare Gems and Loot. Stats, images, and other functionality are intentionally omitted for others to interpret. Feel free to use Enchanted Loot in any way you want.", "image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(output)),
            '"}'
          )
        )
      )
    );
    output = string(abi.encodePacked('data:application/json;base64,', json));

    return output;
  }

  function toString(uint value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

    if (value == 0) {
      return '0';
    }
    uint temp = value;
    uint digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  function onERC721Received(
    address operator,
    address from,
    uint tokenId,
    bytes calldata data
  ) external override inEnchant returns (bytes4) {
    require(msg.sender == address(NFT), 'bad token');
    return this.onERC721Received.selector;
  }

  function onERC1155Received(
    address operator,
    address from,
    uint id,
    uint value,
    bytes calldata data
  ) external override returns (bytes4) {
    revert('unsupported');
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint[] calldata ids,
    uint[] calldata values,
    bytes calldata data
  ) external override inEnchant returns (bytes4) {
    require(msg.sender == address(GEM), 'bad token');
    return this.onERC1155BatchReceived.selector;
  }
}
