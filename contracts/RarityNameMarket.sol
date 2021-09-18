// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/structs/EnumerableSet.sol';

import '../interfaces/IRarity.sol';
import '../interfaces/IName.sol';

/// @dev Rarity Name market to allow trading of names.
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract RarityNameMarket is Initializable, ERC721Holder {
  using EnumerableSet for EnumerableSet.UintSet;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event List(uint indexed id, address indexed lister, string indexed name, uint price);
  event Unlist(uint indexed id, address indexed lister);
  event Buy(uint indexed id, address indexed seller, address indexed buyer, uint price, uint fee);
  event SetFeeBps(uint feeBps);

  IRarity public constant RM = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
  IName public nft;
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
  function initialize(IName _nft, uint _feeBps) external initializer {
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

  /// @dev Lists the given name. This contract will take custody until bought / unlisted.
  function list(uint _nameId, uint _price) external nonReentrant {
    require(_price > 0, 'bad price');
    require(prices[_nameId] == 0, 'already listed');

    uint summonerId = RM.next_summoner();
    RM.summon(11);

    nft.assign_name(_nameId, summonerId);

    prices[_nameId] = _price;
    listers[_nameId] = msg.sender;
    set.add(_nameId);
    mySet[msg.sender].add(_nameId);
    emit List(_nameId, msg.sender, nft.names(_nameId), _price);
  }

  /// @dev Unlists the given name. Must be the lister.
  function unlist(uint _nameId, uint _targetSummonerId) external nonReentrant {
    require(prices[_nameId] > 0, 'not listed');
    require(listers[_nameId] == msg.sender, 'not lister');
    prices[_nameId] = 0;
    listers[_nameId] = address(0);

    nft.assign_name(_nameId, _targetSummonerId);

    set.remove(_nameId);
    mySet[msg.sender].remove(_nameId);
    emit Unlist(_nameId, msg.sender);
  }

  /// @dev Buys the given name. Must pay the exact correct prirce.
  function buy(uint _nameId, uint _targetSummonerId) external payable nonReentrant {
    uint price = prices[_nameId];
    require(price > 0, 'not listed');
    require(msg.value == price, 'bad value');
    uint fee = (price * feeBps) / 10000;
    uint get = price - fee;
    address lister = listers[_nameId];
    prices[_nameId] = 0;
    listers[_nameId] = address(0);

    nft.assign_name(_nameId, _targetSummonerId);

    payable(lister).transfer(get);
    set.remove(_nameId);
    mySet[lister].remove(_nameId);
    emit Buy(_nameId, lister, msg.sender, price, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint _amount) external onlyOwner {
    payable(msg.sender).transfer(_amount == 0 ? address(this).balance : _amount);
  }

  /// @dev Returns list the total number of listed names.
  function listLength() external view returns (uint) {
    return set.length();
  }

  /// @dev Returns the ids and the prices of the listed names.
  function listsAt(uint start, uint count)
    external
    view
    returns (
      uint[] memory rIds,
      string[] memory rNames,
      uint[] memory rPrices
    )
  {
    rIds = new uint[](count);
    rNames = new string[](count);
    rPrices = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = set.at(start + idx);
      rNames[idx] = nft.names(rIds[idx]);
      rPrices[idx] = prices[rIds[idx]];
    }
  }

  /// @dev Returns list the total number of listed names of the given user.
  function myListLength(address user) external view returns (uint) {
    return mySet[user].length();
  }

  /// @dev Returns the ids and the prices of the listed names of the given user.
  function myListsAt(
    address user,
    uint start,
    uint count
  )
    external
    view
    returns (
      uint[] memory rIds,
      string[] memory rNames,
      uint[] memory rPrices
    )
  {
    rIds = new uint[](count);
    rNames = new string[](count);
    rPrices = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = mySet[user].at(start + idx);
      rNames[idx] = nft.names(rIds[idx]);
      rPrices[idx] = prices[rIds[idx]];
    }
  }
}
