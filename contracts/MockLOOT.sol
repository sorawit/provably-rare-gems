// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract MockLOOT is ERC721Enumerable {
  constructor() ERC721('Mock Loot', 'MOCKLOOT') {}

  function mint(address to, uint id) external {
    _safeMint(to, id);
  }
}
