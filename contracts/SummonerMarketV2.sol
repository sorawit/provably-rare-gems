// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/utils/ERC721Holder.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

/// @dev Summoner market to allow trading of summoners
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract SummonerMarketV2 is Initializable, ERC721Holder {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event List(uint indexed id, address indexed lister, uint price);
  event Buy(uint indexed id, address indexed seller, address indexed buyer, uint price, uint fee);
  event SetFeeBps(uint feeBps);

  IERC721 public rarity;
  uint public feeBps;
  address public owner;
  uint private lock;
  mapping(address => mapping(uint => uint)) public prices;

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

  /// @dev Updates listing price for the given summoner.
  function update(uint summonerId, uint price) external nonReentrant {
    if (price > 0) {
      require(rarity.ownerOf(summonerId) == msg.sender, 'not summoner owner');
      require(rarity.isApprovedForAll(msg.sender, address(this)), 'not approved');
    } else {
      require(prices[msg.sender][summonerId] > 0, 'already zero');
    }
    prices[msg.sender][summonerId] = price;
    emit List(summonerId, msg.sender, price);
  }

  /// @dev Buys the given summoner. Must pay the exact correct prirce.
  function buy(uint summonerId) external payable nonReentrant {
    address lister = rarity.ownerOf(summonerId);
    uint price = prices[lister][summonerId];
    require(price > 0, 'not listed');
    require(msg.value == price, 'bad msg.value');
    uint fee = (price * feeBps) / 10000;
    uint get = price - fee;
    prices[lister][summonerId] = 0;
    rarity.safeTransferFrom(lister, msg.sender, summonerId);
    payable(lister).transfer(get);
    emit Buy(summonerId, lister, msg.sender, price, fee);
  }

  /// @dev Withdraw trading fees. Only called by owner.
  function withdraw(uint amount) external onlyOwner {
    payable(msg.sender).transfer(amount == 0 ? address(this).balance : amount);
  }
}
