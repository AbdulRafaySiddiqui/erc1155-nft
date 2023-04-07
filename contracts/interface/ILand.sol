// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./IBaseStruct.sol";

interface ILand is IERC721 {
  function mintLand(uint256 _amount, address _buyer, int256[] memory _coordinates) external;
  function convertTo2dCoordinates(int256[] memory flattenedArray)external returns (int256[2][4] memory);
  function tokenId() external returns (uint256);
}
