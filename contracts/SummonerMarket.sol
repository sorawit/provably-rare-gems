// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

/// @dev Summoner market to allow trading of summoners
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract SummonnerMarket is Initializable, ERC721Holder {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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

  function initialize(IERC721 _rarity, uint _feeBps) external initializer {
    lock = 1;
    owner = msg.sender;
    rarity = _rarity;
    feeBps = _feeBps;
    emit OwnershipTransferred(address(0), msg.sender);
  }

  function transferOwnership(address _owner) external onlyOwner {
    owner = _owner;
    emit OwnershipTransferred(msg.sender, _owner);
  }

  function setFeeBps(uint _feeBps) external onlyOwner {
    feeBps = _feeBps;
  }

  function list(uint summonerId, uint price) external nonReentrant {
    require(price > 0, 'bad price');
    require(prices[summonerId] == 0, 'already listed');
    rarity.safeTransferFrom(msg.sender, address(this), summonerId);
    prices[summonerId] = price;
    listers[summonerId] = msg.sender;
  }

  function unlist(uint summonerId) external nonReentrant {
    require(prices[summonerId] > 0, 'not listed');
    require(listers[summonerId] == msg.sender, 'not lister');
    prices[summonerId] = 0;
    listers[summonerId] = address(0);
    rarity.safeTransferFrom(address(this), msg.sender, summonerId);
  }

  function buy(uint summonerId) external payable nonReentrant {
    uint price = prices[summonerId];
    require(price > 0, 'not listed');
    require(msg.value == price, 'bad msg.value');
    uint fee = (price * feeBps) / 10000;
    uint get = price - fee;
    prices[summonerId] = 0;
    listers[summonerId] = address(0);
    rarity.safeTransferFrom(address(this), msg.sender, summonerId);
    payable(listers[summonerId]).transfer(get);
  }

  function withdraw(uint amount) external onlyOwner {
    payable(msg.sender).transfer(amount == 0 ? address(this).balance : amount);
  }
}
