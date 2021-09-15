// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/structs/EnumerableSet.sol';

import '../interfaces/IAsset.sol';
import '../interfaces/IRarity.sol';

/// @dev Rarity Crafting Materials (I) market to allow trading of crafting materials.
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract RarityCraftingMaterialsIMarket is Initializable {
  using EnumerableSet for EnumerableSet.UintSet;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event List(uint indexed id, address indexed lister, uint price, uint amount);
  event Unlist(uint indexed id, address indexed lister, uint amount);
  event Buy(
    uint indexed id,
    address indexed seller,
    address indexed buyer,
    uint price,
    uint amount,
    uint fee
  );
  event SetFeeBps(uint feeBps);

  struct Listing {
    address lister;
    uint price;
    uint amount;
  }

  IAsset public asset;
  IRarity public constant RM = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
  uint public SUMMONER_ID;
  uint public feeBps;
  address public owner;
  uint private lock;
  EnumerableSet.UintSet private set;
  mapping(address => EnumerableSet.UintSet) private mySet;

  mapping(uint => Listing) listings;
  uint public orderCount;

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
  function initialize(IAsset _asset, uint _feeBps) external initializer {
    lock = 1;
    owner = msg.sender;
    asset = _asset;
    feeBps = _feeBps;

    SUMMONER_ID = RM.next_summoner();
    RM.summon(11);

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

  /// @dev Lists the given crafting materials. This contract will take custody until bought / unlisted.
  function list(
    uint _id,
    uint _price,
    uint _amount
  ) external nonReentrant {
    require(_price > 0, 'bad price');
    require(_amount > 0, 'bad amount');
    require(RM.ownerOf(_id) == msg.sender || RM.getApproved(_id) == msg.sender, '!approved/owner');
    uint orderCount_ = orderCount; // gas saving
    require(listings[orderCount_].price == 0, 'already listed');

    listings[orderCount_] = Listing({lister: msg.sender, price: _price, amount: _amount});
    set.add(orderCount_);
    mySet[msg.sender].add(orderCount_);
    asset.transferFrom(SUMMONER_ID, _id, SUMMONER_ID, _amount);
    emit List(orderCount_, msg.sender, _price, _amount);
    orderCount++;
  }

  /// @dev Unlists the given crafting materials. Must be the lister.
  function unlist(
    uint _orderId,
    uint _amount,
    uint _outSummonerId
  ) external nonReentrant {
    Listing memory listing = listings[_orderId];
    if (_amount == type(uint).max) _amount = listing.amount;
    require(listing.price > 0, 'not listed');
    require(_amount <= listing.amount, 'bad amount');
    require(_amount > 0, 'zero amount');
    require(listing.lister == msg.sender, 'not lister');
    require(RM.ownerOf(_outSummonerId) == msg.sender, 'bad target');

    if (_amount == listing.amount) {
      listings[_orderId] = Listing({lister: address(0), price: 0, amount: 0});
      set.remove(_orderId);
      mySet[listing.lister].remove(_orderId);
    } else {
      listings[_orderId].amount = listing.amount - _amount;
    }

    asset.transfer(SUMMONER_ID, _outSummonerId, _amount);
    emit Unlist(_orderId, msg.sender, _amount);
  }

  /// @dev Buys the given crafting materials. Must pay the exact correct prirce.
  function buy(
    uint _orderId,
    uint _amount,
    uint _outSummonerId
  ) external payable nonReentrant {
    Listing memory listing = listings[_orderId];
    require(listing.price > 0, 'not listed');
    require(_amount <= listing.amount, 'bad amount');
    require(_amount > 0, 'zero amount');
    require(msg.value == listing.price * _amount, 'bad msg.value');
    require(RM.ownerOf(_outSummonerId) == msg.sender, 'bad target');

    uint fee = (listing.price * _amount * feeBps) / 10000;
    uint get = listing.price * _amount - fee;

    if (listing.amount == _amount) {
      listings[_orderId] = Listing({lister: address(0), price: 0, amount: 0});
      set.remove(_orderId);
      mySet[listing.lister].remove(_orderId);
    } else {
      listings[_orderId].amount = listing.amount - _amount;
    }

    asset.transfer(SUMMONER_ID, _outSummonerId, _amount);
    payable(listing.lister).transfer(get);
    emit Buy(_orderId, listing.lister, msg.sender, listing.price, _amount, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint _amount) external onlyOwner {
    payable(msg.sender).transfer(_amount == 0 ? address(this).balance : _amount);
  }

  /// @dev Returns list the total number of listed crafting materials.
  function listLength() external view returns (uint) {
    return set.length();
  }

  /// @dev Returns the ids, prices, amounts of the listed crafting materials.
  function listsAt(uint start, uint count)
    external
    view
    returns (
      uint[] memory rIds,
      uint[] memory rPrices,
      uint[] memory rAmounts
    )
  {
    rIds = new uint[](count);
    rPrices = new uint[](count);
    rAmounts = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = set.at(start + idx);
      rPrices[idx] = listings[rIds[idx]].price;
      rAmounts[idx] = listings[rIds[idx]].amount;
    }
  }

  /// @dev Returns list the total number of listed crafting materials of the given user.
  function myListLength(address user) external view returns (uint) {
    return mySet[user].length();
  }

  /// @dev Returns the ids, prices, amounts of the listed crafting materials of the given user.
  function myListsAt(
    address user,
    uint start,
    uint count
  )
    external
    view
    returns (
      uint[] memory rIds,
      uint[] memory rPrices,
      uint[] memory rAmounts
    )
  {
    rIds = new uint[](count);
    rPrices = new uint[](count);
    rAmounts = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = mySet[user].at(start + idx);
      rPrices[idx] = listings[rIds[idx]].price;
      rAmounts[idx] = listings[rIds[idx]].amount;
    }
  }
}
