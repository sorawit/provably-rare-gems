// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

/// @dev Summoner market to allow trading of summoners
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract SummonnerMarket is Initializable, ERC721Holder {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event List(uint indexed id, address indexed lister, uint price);
  event Unlist(uint indexed id, address indexed lister);
  event Buy(uint indexed id, address indexed seller, address indexed buyer, uint price, uint fee);
  event SetFeeBps(uint feeBps);

  IERC721 public rarity;
  uint public feeBps;
  address public owner;
  uint private lock;

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
  function initialize(IERC721 _rarity, uint _feeBps) external initializer {
    lock = 1;
    owner = msg.sender;
    rarity = _rarity;
    feeBps = _feeBps;
    emit OwnershipTransferred(address(0), msg.sender);
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

  /// @dev Lists the given summoner. This contract will take custody until bought / unlisted.
  function list(uint summonerId, uint price) external nonReentrant {
    require(price > 0, 'bad price');
    require(prices[summonerId] == 0, 'already listed');
    rarity.safeTransferFrom(msg.sender, address(this), summonerId);
    prices[summonerId] = price;
    listers[summonerId] = msg.sender;
    emit List(summonerId, msg.sender, price);
  }

  /// @dev Unlists the given summoner. Must be the lister.
  function unlist(uint summonerId) external nonReentrant {
    require(prices[summonerId] > 0, 'not listed');
    require(listers[summonerId] == msg.sender, 'not lister');
    prices[summonerId] = 0;
    listers[summonerId] = address(0);
    rarity.safeTransferFrom(address(this), msg.sender, summonerId);
    emit Unlist(summonerId, msg.sender);
  }

  /// @dev Buys the given summoner. Must pay the exact correct prirce.
  function buy(uint summonerId) external payable nonReentrant {
    uint price = prices[summonerId];
    require(price > 0, 'not listed');
    require(msg.value == price, 'bad msg.value');
    uint fee = (price * feeBps) / 10000;
    uint get = price - fee;
    address lister = listers[summonerId];
    prices[summonerId] = 0;
    listers[summonerId] = address(0);
    rarity.safeTransferFrom(address(this), msg.sender, summonerId);
    payable(lister).transfer(get);
    emit Buy(summonerId, lister, msg.sender, price, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint amount) external onlyOwner {
    payable(msg.sender).transfer(amount == 0 ? address(this).balance : amount);
  }
}
