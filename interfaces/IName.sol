pragma solidity 0.8.3;

interface IName {
  function names(uint) external view returns (string memory);

  function assign_name(uint, uint) external;
}
