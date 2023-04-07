// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
    _mint(msg.sender, 10 ether);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }

  function _mint(address account, uint256 amount) internal virtual override {
    ERC20._mint(account, amount);
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }
}
