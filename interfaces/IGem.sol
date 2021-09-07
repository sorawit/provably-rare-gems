pragma solidity 0.8.3;

interface IGem {
  function balanceOf(address, uint) external view returns (uint);

  function gemCount() external view returns (uint);

  function gems(uint)
    external
    view
    returns (
      string memory,
      string memory,
      bytes32,
      uint,
      uint,
      uint,
      address,
      address,
      address
    );
}
