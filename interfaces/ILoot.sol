pragma solidity 0.8.3;

interface ILoot {
  function getWeapon(uint) external view returns (string memory);

  function getChest(uint) external view returns (string memory);

  function getHead(uint) external view returns (string memory);

  function getWaist(uint) external view returns (string memory);

  function getFoot(uint) external view returns (string memory);

  function getHand(uint) external view returns (string memory);

  function getNeck(uint) external view returns (string memory);

  function getRing(uint) external view returns (string memory);
}
