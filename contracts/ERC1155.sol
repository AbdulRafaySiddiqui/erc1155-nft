// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./ReferralSystem.sol";
import "./IUniswapV2Pair.sol";

contract Ticket is ERC1155, ReferralSystem {
  //Fixed Token Id
  uint256 public constant TOKENID = 0;

  struct Level {
    // no. of sales done by referrer, required to be in this level
    uint256 requiredSales;
    // discount for users, whose referrer is on this level
    uint256 discount;
    // referrer will receive an airdrop after selling this number of tokens each time
    uint256 salesPerAirdrop;
  }

  // Used to properly calculates eth price with usdc with more presice value
  uint256 public constant PRECISION = 100000;

  // referral token sale levels
  Level[] public levels;

  // In USDC
  // TODO: use correct and descriptive naming
  uint256 public airdropPrice = 8;

  //Quantity For Individual referrer
  uint256 public airdropQuantity = 1;

  //Quantity For brand referrer
  uint256 public airdropQuantityBrand = 1;

  // brand referrer will receive an airdrop after selling this number of tokens each time
  uint256 public salesPerBrandAirdrop = 3;

  // user discount for brand referrer
  uint256 public discountBrand = 25;

  //Minting stoping time
  uint256 public mintingStopTime;

  //To start and stop minting
  bool public mintEnabled = true;

  //Switch between eth airdrop or Ticket airdrop
  bool public ethAirdropEnabled = true;
  //Wert address
  address public wertEstimationAddress;
  address public wertTransactionAddress;

  // Pair address for usdc/eth
  IUniswapV2Pair public pair;

  //Usdc address
  address usdcAddress;

  event LevelCreated(uint256 requiredSales, uint256 discount, uint256 airdrop);
  event UpdateTokenAirDropPrice(uint256 airdropPrice);
  event UpdatePartnerShipAirdrop(uint256 salesPerBrandAirdrop);
  event UpdateMintingTime(uint256 mintingStopTime);
  event UpdateToggleMint(bool toggleMint);
  event UpdateAirDropQuantity(uint256 airdropQuantity);
  event UpdateAirDropQuantityPartnerShip(uint256 airdropQuantityBrand);
  event UpdatePartnerShipDiscount(uint256 discountBrand);
  event ReferrerAirdropAmountInEth(address referrer, uint256 amount);

  constructor(
    string memory _uri,
    address _wertEstimationAddress,
    address _wertTransactionAddress,
    IUniswapV2Pair _pair,
    address _usdcAddress
  ) ERC1155(_uri) {
    wertEstimationAddress = _wertEstimationAddress;
    wertTransactionAddress = _wertTransactionAddress;
    pair = _pair;
    _usdcAddress = usdcAddress;
    mintingStopTime = block.timestamp + 30 days;
  }

  //Should add levels in ascending order of sales
  function createLevels(Level[] calldata _levels) external onlyOwner {
    require(_levels.length > 0, "Tickets: Zero Levels");
    for (uint256 i = 0; i < _levels.length; i++) {
      // every ascending level should have a greater sales number than the previous one
      if (levels.length != 0) {
        require(_levels[i].requiredSales > levels[levels.length - 1].requiredSales, "Ticket: Levels are not in order");
      }
      levels.push(_levels[i]);
      emit LevelCreated(_levels[i].requiredSales, _levels[i].discount, _levels[i].salesPerAirdrop);
    }
  }

  function mint(
    uint256 _amount,
    address _buyer,
    string calldata _referrerTwitterHandle,
    string calldata _buyerTwitterHandle
  ) external payable {
    //For production uncomment this code
    require(msg.sender == wertEstimationAddress || msg.sender == wertTransactionAddress, "Only Wert Address call this");
    require(mintEnabled && block.timestamp < mintingStopTime, "Ticket:Minting paused");

    require(_amount != 0, "Ticket:Invalid amount");
    require(bytes(_referrerTwitterHandle).length <= 15, "Ticket:Invalid referrer Twitter handle");

    require(bytes(_buyerTwitterHandle).length <= 15, "Ticket:Invalid buyer Twitter handle");

    if (bytes(_buyerTwitterHandle).length > 0) {
      createReferralForAccount(_buyer, _buyerTwitterHandle);
    }

    if (bytes(_referrerTwitterHandle).length > 0) {
      (address _referrer, address _brandReferrer) = _validateReferrer(_buyer, _referrerTwitterHandle);
      _referrerAirdrop(_referrer, _brandReferrer, _amount);
    }

    _mint(_buyer, TOKENID, _amount, bytes(_referrerTwitterHandle));
  }

  function _referrerAirdrop(address _referrer, address _brandReferrer, uint256 amount) internal {
    require(_referrer != address(0) || _brandReferrer != address(0), "Ticket: Referrer does not exist");
    if (_referrer != address(0)) {
      //Holds current token sales for referrer
      referrerCurrentLevelSales[_referrer] += amount;
      //Holds overall tokens sales for referrer
      referrerTokenSales[_referrer] += amount;

      Level memory currentReferrerLevel;

      // find the current level of referrer
      for (uint256 i = 0; i < levels.length; i++) {
        if (referrerTokenSales[_referrer] >= levels[i].requiredSales) {
          currentReferrerLevel = levels[i];
        } else {
          // levels are in incremental order of required sales, so if any level's required sales is not matched, we should break here
          break;
        }
      }

      // if salesPerAirdrop is zero, means the referrer don't have any level,
      // or if he don't have any sales in this level, we don't need to airdrop anything
      if (
        currentReferrerLevel.salesPerAirdrop > 0 &&
        referrerCurrentLevelSales[_referrer] >= currentReferrerLevel.salesPerAirdrop
      ) {
        /**
         * if we divide the current level sales by salesPerAirdrop, we get the amount of tokens to airdrop
         * E.g: currentLevelSales = 13 and salesPerAirdrop = 5
         * uint256 amountToAirdrop = currentLevelSales / salesPerAirdrop = 13 / 5 = 10
         *
         * In order to get the remaining tokens that are not included in the airdrop, we subtract the currentLevelSales from
         * the multiple of salesPerAirdrop * amountToAirdrop
         * E.g: currentLevelSales = currentLevelSales - (salesPerAirdrop * amountToAirdrop) = 13 - (5 * 2) = 3
         */
        uint256 amountToAirdrop = referrerCurrentLevelSales[_referrer] / currentReferrerLevel.salesPerAirdrop;
        referrerCurrentLevelSales[_referrer] =
          referrerCurrentLevelSales[_referrer] -
          (currentReferrerLevel.salesPerAirdrop * amountToAirdrop);

        _airdrop(airdropQuantity, amountToAirdrop, _referrer);
      }
    } else {
      brandReferrerCurrentTokenSales[_brandReferrer] += amount;
      brandReferrerTokenSales[_brandReferrer] += amount;

      // See the above comment for normal referral airdrop
      if (salesPerBrandAirdrop > 0 && brandReferrerCurrentTokenSales[_brandReferrer] >= salesPerBrandAirdrop) {
        uint256 amountToAirdrop = brandReferrerCurrentTokenSales[_brandReferrer] / salesPerBrandAirdrop;
        brandReferrerCurrentTokenSales[_brandReferrer] =
          brandReferrerCurrentTokenSales[_brandReferrer] -
          (salesPerBrandAirdrop * amountToAirdrop);

        _airdrop(airdropQuantityBrand, amountToAirdrop, _brandReferrer);
      }
    }
  }

  function setWertAddresses(address _wertEstimatior, address _wertTransaction) external onlyOwner {
    wertEstimationAddress = _wertEstimatior;
    wertTransactionAddress = _wertTransaction;
  }

  function _airdrop(uint256 _airDropQuantity, uint256 _airDropAmount, address _referrer) internal {
    if (ethAirdropEnabled) {
      //Gives Eth to referrer
      uint256 _amount = calculateTokenPriceInWei(_airDropQuantity * _airDropAmount);
      require(address(this).balance >= _amount, "Ticket:Insufficient balance");
      payable(_referrer).transfer(_amount);
      emit ReferrerAirdropAmountInEth(_referrer, _amount);
    } else {
      //Give Tickets to referrer
      _mint(_referrer, TOKENID, _airDropQuantity * _airDropAmount, "");
    }
  }

  // Calculate Eth amount in usd $
  function calculateTokenPriceInWei(uint256 _amount) public view returns (uint256) {
    address token0 = pair.token0();
    uint256 PerUsdcPriceInEth;
    if (token0 == usdcAddress) {
      (uint112 usdcAmount, uint112 ethAmount, ) = pair.getReserves();

      //calculcate 1 usdc price in eth
      PerUsdcPriceInEth = ((ethAmount * PRECISION) / (usdcAmount * 10 ** 12));
    } else {
      (uint112 ethAmount, uint112 usdcAmount, ) = pair.getReserves();

      //calculcate 1 usdc price in eth
      PerUsdcPriceInEth = ((ethAmount * PRECISION) / (usdcAmount * 10 ** 12));
    }

    uint256 tokenAPriceInWei = ((PerUsdcPriceInEth * airdropPrice) * 1e18) / PRECISION;

    return (tokenAPriceInWei * _amount);
  }

  function calculateUserDiscount(
    address _buyer,
    string calldata _twitterHandle
  ) external view returns (uint256 discount) {
    require(bytes(_twitterHandle).length >= 0, "Ticket:Invalid Referral");
    (address referrer, address brandReferrer) = _validateReferrer(_buyer, _twitterHandle);
    require(referrer != address(0) || brandReferrer != address(0), "Ticket: Referrer does not exist");

    if (referrer != address(0)) {
      Level memory currentReferrerLevel;

      // find the current level of referrer
      for (uint256 i = 0; i < levels.length; i++) {
        if (referrerTokenSales[referrer] >= levels[i].requiredSales) {
          currentReferrerLevel = levels[i];
        } else {
          // levels are in incremental order of required sales, so if any level's required sales is not matched, we should break here
          break;
        }
      }
      //If the referrer is at any level, provide the discount associated with their referral
      //otherwise returns zero
      if (currentReferrerLevel.salesPerAirdrop > 0) {
        return currentReferrerLevel.discount;
      } else {
        return 0;
      }
    } else {
      return discountBrand;
    }
  }

  function burn(uint256 id, uint256 amount) external {
    _burn(_msgSender(), id, amount);
  }

  function withdraw() external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "Ticket:No balance to withdraw");
    (bool success, ) = payable(msg.sender).call{value: balance}("");
    require(success, "Ticket:Withdraw failed");
  }

  function setBrandDiscount(uint256 _amount) external onlyOwner {
    discountBrand = _amount;
    emit UpdatePartnerShipDiscount(discountBrand);
  }

  function setAirdropQuantity(uint256 _quantity) external onlyOwner {
    airdropQuantity = _quantity;
    emit UpdateAirDropQuantity(airdropQuantity);
  }

  function setAirdropQuantityPartnerShip(uint256 _quantity) external onlyOwner {
    airdropQuantityBrand = _quantity;
    emit UpdateAirDropQuantityPartnerShip(airdropQuantityBrand);
  }

  function setBrandAirdrop(uint256 _amount) external onlyOwner {
    salesPerBrandAirdrop = _amount;
    emit UpdatePartnerShipAirdrop(salesPerBrandAirdrop);
  }

  function setToggleEthAirdrop(bool value) external onlyOwner {
    ethAirdropEnabled = value;
  }

  function setToggleMinting(bool _val) external onlyOwner {
    mintEnabled = _val;
    emit UpdateToggleMint(_val);
  }

  //Has to be in USDC
  function setAirdropPrice(uint256 _amount) external onlyOwner {
    airdropPrice = _amount;
    emit UpdateTokenAirDropPrice(airdropPrice);
  }

  function setMintingTime(uint256 _value) external onlyOwner {
    mintingStopTime = block.timestamp + _value;
    emit UpdateMintingTime(mintingStopTime);
  }

  function setUsdcAddress(address _address) external onlyOwner {
    usdcAddress = _address;
  }

  function setURI(string memory newuri) external onlyOwner {
    _setURI(newuri);
  }

  function setPair(IUniswapV2Pair _pair) external onlyOwner {
    pair = _pair;
  }

  receive() external payable {}
}