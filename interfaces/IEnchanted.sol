pragma solidity 0.8.3;

interface IEnchanted {
  function enchant(
    uint,
    uint[] memory,
    uint[] memory
  ) external;

  function disenchant(uint) external;

  function tokenURI(uint) external view returns (string memory);
}
