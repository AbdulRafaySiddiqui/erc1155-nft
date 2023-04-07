// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ReferralSystem is Ownable {
  // TODO: add description, change name to referrerTokenSales
  mapping(address => uint256) public referrerTokenSales;
  mapping(address => uint256) public referrerCurrentLevelSales;

  //Twitter handles indivisuals
  mapping(string => address) public twitterHandleToAddress;
  mapping(address => string) public addressToTwitterHandle;

  //Twitter handle partnership
  mapping(address => uint256) public brandReferrerCurrentTokenSales;
  mapping(address => uint256) private brandReferrerTokenSales;

  mapping(string => address) public twitterHandleToPartnership;
  mapping(address => string) public partnershipToTwitterHandle;
  mapping(address => uint256) public brandReferralTokenSales;


  function _validateReferrer(
    address _buyer,
    string calldata _twitterHandle
  ) internal view returns (address referrer, address brandReferrer) {
    address _referrer = twitterHandleToAddress[_twitterHandle];
    address _brandReferrer = twitterHandleToPartnership[_twitterHandle];

    // if referrer is the buyer itself (means invalid referrer), return no referrer or partner referrer
    if (_referrer == _buyer || _brandReferrer == _buyer) return (address(0), address(0));

    // if referrer is a partner, return partner address, partner has first priority over normal referrer
    if (_brandReferrer != address(0)) return (address(0), _brandReferrer);

    // if referrer is normal user, return referrer address
    if (_referrer != address(0)) return (_referrer, address(0));

    // no referrer found
    return (address(0), address(0));
  }

  function createReferralForAccount(address _account, string calldata _twitterHandle) public {
    require(_account != address(0), "ReferralSystem: Invalid address");

    // if referral already exists, just return
    if (bytes(addressToTwitterHandle[_account]).length != 0) return;

    // if no referral already exist, create one

    require(bytes(_twitterHandle).length > 0 && bytes(_twitterHandle).length < 15,"ReferralSystem: Invalid twitter handle");
    require(twitterHandleToAddress[_twitterHandle] == address(0), "ReferralSystem: Twitter handle already in use")

    twitterHandleToAddress[_twitterHandle] = _account;
    addressToTwitterHandle[_account] = _twitterHandle;
  }

  function createReferralCodeForPartnerShip(address _account, string calldata _twitterHandle) external onlyOwner {
    require(_account != address(0), "ReferralSystem:Invalid address");
    require(bytes(partnershipToTwitterHandle[_account]).length == 0, "ReferralSystem: Referrer already exists");
    require(
      bytes(_twitterHandle).length > 0 && bytes(_twitterHandle).length < 15,
      "ReferralSystem: Invalid twitter handle"
    );
    partnershipToTwitterHandle[_account] = _twitterHandle;
    twitterHandleToPartnership[_twitterHandle] = _account;
  }
}
