// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interface/ILand.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interface/IBaseStruct.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Sale is AccessControlEnumerable, Ownable {
  using ECDSA for bytes32;

  mapping(bytes32 => bool) boughtOrCanceledHash;

  struct LandSale {
    address userAddress;
    uint256 amount;
    uint256 deadline;
    bytes signature;
    int256[] coordinates;
  }

  ILand public landNFT;

  bytes32 public constant SALE_SIGNER_ROLE = keccak256("SALE_SIGNER_ROLE");
  bytes32 public constant LAND_SALE_TYPEHASH =
    keccak256("LandSale(address userAddress,uint256 amount,uint256 deadline,int256[] coordinates)");
  bytes32 public DOMAIN_SEPARATOR;

  event MintLand(address indexed buyer, uint256 indexed tokenId, int[2][4] coordinates);

  constructor(ILand _landNFT) {
    landNFT = _landNFT;

    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("Sale")),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(SALE_SIGNER_ROLE, msg.sender);
  }

  function buy(LandSale memory landSale) external payable {
    _verifySignature(landSale);
    _mintToken(landSale);
    int[2][4] memory coordinateArr = landNFT.convertTo2dCoordinates(landSale.coordinates);
    uint tokenId = landNFT.tokenId();
    emit MintLand(landSale.userAddress, tokenId, coordinateArr);
  }

  function _verifySignature(LandSale memory landSale) internal {
    bytes32 digest = DOMAIN_SEPARATOR.toTypedDataHash(
      keccak256(
        abi.encode(
          LAND_SALE_TYPEHASH,
          landSale.userAddress,
          landSale.amount,
          landSale.deadline,
          keccak256(abi.encodePacked(landSale.coordinates))
        )
      )
    );
    address signer = digest.recover(landSale.signature);
    require(hasRole(SALE_SIGNER_ROLE, signer), "Invalid signature");

    require(!boughtOrCanceledHash[digest], "Signature already used or canceled");
    boughtOrCanceledHash[digest] = true;
  }

  function _mintToken(LandSale memory landSale) internal {
    landNFT.mintLand(landSale.amount, landSale.userAddress, landSale.coordinates);
  }

  function setLand(ILand _landNFT) external onlyOwner {
    landNFT = _landNFT;
  }
}
