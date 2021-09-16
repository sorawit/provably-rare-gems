// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC20/IERC20.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/structs/EnumerableSet.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/utils/math/SafeCast.sol';

import '../interfaces/IAsset.sol';
import '../interfaces/IRarity.sol';

/// @dev Rarity Crafting Materials (I) market to allow trading of crafting materials.
/// @author swit.eth (@nomorebear) + nipun (@nipun_pit) + jade (@jade_arin)
contract RarityCraftingMaterialsIMarket is Initializable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeCast for uint;
  using SafeCast for int;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event Modify(
    address indexed lister,
    uint indexed price,
    int modifyAmount,
    uint indexed summonerId
  );
  event Buy(
    address indexed lister,
    address indexed buyer,
    uint indexed price,
    uint buyAmount,
    uint summonerId,
    uint minPrice
  );
  event SetFeeBps(uint feeBps);

  IAsset public asset;
  IRarity public constant RM = IRarity(0xce761D788DF608BD21bdd59d6f4B54b2e27F25Bb);
  uint public SUMMONER_ID;
  uint public feeBps;
  address public owner;
  uint private lock;
  EnumerableSet.AddressSet private set;

  mapping(address => uint) prices;
  mapping(address => uint) amounts;

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

  function _isApprovedOrOwner(uint _summoner) internal view returns (bool) {
    return RM.getApproved(_summoner) == msg.sender || RM.ownerOf(_summoner) == msg.sender;
  }

  /// @dev Modifies order, providing new price and delta amount (can be negative).
  /// @param _price New price to set to.
  /// @param _amount Delta amount to modify. Negative means less amount.
  /// @param _summonerId Target summoner id to transfer asset to/from.
  function modify(
    uint _price,
    int _amount,
    uint _summonerId
  ) external nonReentrant {
    require(_isApprovedOrOwner(_summonerId), '!approved');
    uint oldAmount = amounts[msg.sender];
    uint newAmount = int(oldAmount.toInt256() + _amount).toUint256();
    if (newAmount > 0) {
      require(_price > 0, '!price');
    }
    uint oldValue = prices[msg.sender] * oldAmount;
    uint newValue = _price * newAmount;

    prices[msg.sender] = _price;
    amounts[msg.sender] = newAmount;

    if (oldValue < newValue) {
      asset.transferFrom(SUMMONER_ID, _summonerId, SUMMONER_ID, newValue - oldValue);
    } else if (newValue < oldValue) {
      asset.transfer(SUMMONER_ID, _summonerId, oldValue - newValue);
    }

    if (_amount > 0 && newAmount == 0) {
      set.remove(msg.sender);
    } else if (_amount == 0 && newAmount > 0) {
      set.add(msg.sender);
    }

    emit Modify(msg.sender, _price, _amount, _summonerId);
  }

  /// @dev Buys the given crafting materials.
  /// @param _lister Order lister address.
  /// @param _buyAmount Desired amount to buy.
  /// @param _summonerId Target summoner id to receive asset
  /// @param _maxPrice Slippage control.
  function buy(
    address _lister,
    uint _buyAmount,
    uint _summonerId,
    uint _maxPrice
  ) external payable nonReentrant {
    uint price = prices[_lister];
    uint amount = amounts[_lister];
    require(_isApprovedOrOwner(_summonerId), '!approved');
    require(_buyAmount <= amount, '!amount');
    require(price <= _maxPrice, '!maxPrice');
    uint buyValue = price * _buyAmount;
    require(msg.value >= buyValue, '!value');

    amounts[msg.sender] -= _buyAmount;
    asset.transfer(SUMMONER_ID, _summonerId, _buyAmount);

    // remaining amount = 0
    if (amount == _buyAmount) {
      set.remove(msg.sender);
    }

    // refund over-paid amount
    if (msg.value > buyValue) {
      payable(msg.sender).transfer(msg.value - buyValue);
    }

    emit Buy(_lister, msg.sender, price, _buyAmount, _summonerId, _maxPrice);
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
      address[] memory rIds,
      uint[] memory rPrices,
      uint[] memory rAmounts
    )
  {
    rIds = new address[](count);
    rPrices = new uint[](count);
    rAmounts = new uint[](count);
    for (uint idx = 0; idx < count; idx++) {
      rIds[idx] = set.at(start + idx);
      rPrices[idx] = prices[rIds[idx]];
      rAmounts[idx] = amounts[rIds[idx]];
    }
  }
}
