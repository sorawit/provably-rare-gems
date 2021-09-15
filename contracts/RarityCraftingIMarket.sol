// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/structs/EnumerableSet.sol';

import '../interfaces/ICrafting.sol';

/// @dev Rarity Crafting (I) market to allow trading of crafted items.
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract RarityCraftingIMarket is Initializable, ERC721Holder {
  using EnumerableSet for EnumerableSet.UintSet;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event List(uint indexed id, address indexed lister, uint price);
  event ListInfo(
    uint indexed id,
    uint8 indexed base_type,
    uint8 indexed item_type,
    uint32 crafted,
    uint crafter
  );
  event Unlist(uint indexed id, address indexed lister);
  event Buy(uint indexed id, address indexed seller, address indexed buyer, uint price, uint fee);
  event SetFeeBps(uint feeBps);

  IERC721 public nft;
  uint public feeBps;
  address public owner;
  uint private lock;
  EnumerableSet.UintSet private set;
  mapping(address => EnumerableSet.UintSet) private mySet;

  mapping(uint => uint) public prices;
  mapping(uint => address) public listers;

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

  /// @dev Initializes the contract. Can only be called once.
  function initialize(IERC721 _nft, uint _feeBps) external initializer {
    lock = 1;
    owner = msg.sender;
    nft = _nft;
    feeBps = _feeBps;
    emit OwnershipTransferred(address(0), msg.sender);
    emit SetFeeBps(_feeBps);
  }

  /// @dev Transfers ownership to a new address.
  function transferOwnership(address _owner) external onlyOwner {
    owner = _owner;
    emit OwnershipTransferred(msg.sender, _owner);
  }

  /// @dev Updates fee. Only callable by owner.
  function setFeeBps(uint _feeBps) external onlyOwner {
    feeBps = _feeBps;
    emit SetFeeBps(_feeBps);
  }

  /// @dev NFT-specific function for tracking listing info.
  function emitListInfo(uint _id) internal {
    (uint8 base_type, uint8 item_type, uint32 crafted, uint crafter) = ICrafting(address(nft))
      .items(_id);
    emit ListInfo(_id, base_type, item_type, crafted, crafter);
  }

  /// @dev Lists the given crafting. This contract will take custody until bought / unlisted.
  function list(uint _id, uint _price) external nonReentrant {
    require(_price > 0, 'bad price');
    require(prices[_id] == 0, 'already listed');
    nft.safeTransferFrom(msg.sender, address(this), _id);
    prices[_id] = _price;
    listers[_id] = msg.sender;
    set.add(_id);
    mySet[msg.sender].add(_id);
    emit List(_id, msg.sender, _price);
    emitListInfo(_id);
  }

  /// @dev Unlists the given crafting. Must be the lister.
  function unlist(uint _id) external nonReentrant {
    require(prices[_id] > 0, 'not listed');
    require(listers[_id] == msg.sender, 'not lister');
    prices[_id] = 0;
    listers[_id] = address(0);
    nft.safeTransferFrom(address(this), msg.sender, _id);
    set.remove(_id);
    mySet[msg.sender].remove(_id);
    emit Unlist(_id, msg.sender);
  }

  /// @dev Buys the given crafting. Must pay the exact correct prirce.
  function buy(uint _id) external payable nonReentrant {
    uint price = prices[_id];
    require(price > 0, 'not listed');
    require(msg.value == price, 'bad msg.value');
    uint fee = (price * feeBps) / 10000;
    uint get = price - fee;
    address lister = listers[_id];
    prices[_id] = 0;
    listers[_id] = address(0);
    nft.safeTransferFrom(address(this), msg.sender, _id);
    payable(lister).transfer(get);
    set.remove(_id);
    mySet[lister].remove(_id);
    emit Buy(_id, lister, msg.sender, price, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint _amount) external onlyOwner {
    payable(msg.sender).transfer(_amount == 0 ? address(this).balance : _amount);
  }

  /// @dev Returns list the total number of listed craftings.
  function listLength() external view returns (uint) {
    return set.length();
  }

  /// @dev Returns the ids and the prices of the listed craftings.
  function listsAt(uint start, uint count)
    external
    view
    returns (uint[] memory rIds, uint[] memory rPrices)
  {
    rIds = new uint[](count);
    rPrices = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = set.at(start + idx);
      rPrices[idx] = prices[rIds[idx]];
    }
  }

  /// @dev Returns list the total number of listed craftings of the given user.
  function myListLength(address user) external view returns (uint) {
    return mySet[user].length();
  }

  /// @dev Returns the ids and the prices of the listed craftings of the given user.
  function myListsAt(
    address user,
    uint start,
    uint count
  ) external view returns (uint[] memory rIds, uint[] memory rPrices) {
    rIds = new uint[](count);
    rPrices = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = mySet[user].at(start + idx);
      rPrices[idx] = prices[rIds[idx]];
    }
  }
}
