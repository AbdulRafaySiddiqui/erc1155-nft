// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./Ticket.sol";
import "./interface/ILand.sol";

contract Land is ILand, ERC721, Ownable, ERC1155Holder, AccessControlEnumerable {
  //Holds coordinatedata of tokenIds
  mapping(uint256 => CoordinatesData) tokenIdCoordinatesData;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // Instance for Ticket contract
  Ticket public Ticket;

  uint256 public nextTokenId = 1;

  //Only given amount of Tickets are allowed to mint land
  uint256[] public allowedTicketsAmount = [8, 32, 128, 512, 2048];

  event TicketContract(Ticket Ticket);

  constructor(string memory _name, string memory _symbol, Ticket _Ticket) ERC721(_name, _symbol) {
    Ticket = _Ticket;
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
  }

  function getCoordinatesData(uint256 _tokenId) external view returns (CoordinatesData memory _coordinates) {
    return _coordinates = tokenIdCoordinatesData[_tokenId];
  }

  /* A user can only buy if
    - He approves his Tickets to land contract before buying land
    - Gives valid amount of Tickets
    - Has enough balance of Tickets to buy land
  */

  function mintLand(uint256 _amount, address _buyer, CoordinatesData memory _coordinates) external virtual override {
    require(hasRole(MINTER_ROLE, _msgSender()), "Land:Only minter");
    require(isValidAmount(_amount), "Land:Invalid amount");
    uint TicketTokenId = Ticket.TOKENID();
    require(Ticket.balanceOf(_buyer, TicketTokenId) >= _amount, "Land:Not enough Ticket balance");

    tokenIdCoordinatesData[nextTokenId] = _coordinates;

    //Send Tickets to land contract
    Ticket.safeTransferFrom(_buyer, address(this), TicketTokenId, _amount, "");

    //Burn Tickets 
    Ticket.burn(TicketTokenId, _amount);

    _safeMint(_buyer, nextTokenId);

    nextTokenId++;
  }

  function tokenId() external virtual override returns (uint256) {
    return nextTokenId - 1;
  }

  function isValidAmount(uint256 _amount) internal view returns (bool) {
    for (uint256 i = 0; i < allowedTicketsAmount.length; i++) {
      if (_amount == allowedTicketsAmount[i]) {
        return true;
      }
    }
    return false;
  }

  function addAllowedTicketsAmount(uint256 _amount) external onlyOwner {
    allowedTicketsAmount.push(_amount);
  }

  function setTicket(Ticket _Ticket) external onlyOwner {
    Ticket = _Ticket;
  }

  function removeTicketsAmount(uint256 _amount) external onlyOwner {
    uint256 indexToRemove = allowedTicketsAmount.length + 1;

    for (uint256 i = 0; i < allowedTicketsAmount.length; i++) {
      if (allowedTicketsAmount[i] == _amount) {
        indexToRemove = i;
        break;
      }
    }

    require(indexToRemove < allowedTicketsAmount.length, "Land: Amount not found");

    allowedTicketsAmount[indexToRemove] = allowedTicketsAmount[allowedTicketsAmount.length - 1];
    allowedTicketsAmount.pop();
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerable, ERC1155Receiver, ERC721, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}