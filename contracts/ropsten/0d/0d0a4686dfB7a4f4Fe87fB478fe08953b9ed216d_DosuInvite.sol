// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DosuInvite is ERC721, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  address public treasure;
  uint public txFeeAmount;
  uint public totalInvites;
  
  mapping(address => bool) internal excludedList;

  struct Invite {
    address ethAddress;
    uint256 tokenId;
  }

  event Mint(address to, uint256 tokenId);

  Invite[] public mintedInvites;

  constructor(
    address _treasure, 
    uint _txFeeAmount,
    uint _totalInvites
  ) ERC721("Dosu Invites", "DOSU") {
    treasure = _treasure;
    txFeeAmount = _txFeeAmount;
    totalInvites = _totalInvites;

    excludedList[_treasure] = true; 
    _mint(treasure, 0);
  }

  function setExcluded(address excluded, bool status) external {
    require(msg.sender == treasure, "treasure only");
    excludedList[excluded] = status;
  }

  function mint(address _to) public onlyOwner  {
    // require(balanceOf(_to) >= 1, "This address already have an invite");
    
    _tokenIds.increment();

    uint256 newInviteId = _tokenIds.current();
    _mint(_to, newInviteId);
    emit Mint(_to, newInviteId);

    Invite memory invite = Invite({tokenId: newInviteId, ethAddress: _to});
    mintedInvites.push(invite);
  }

  function transferFrom(
    address from, 
    address to, 
    uint256 tokenId
  ) public payable override {
     require(
       _isApprovedOrOwner(_msgSender(), tokenId), 
       "ERC721: transfer caller is not owner nor approved"
     );
     if(excludedList[from] == false) {
      _payTxFee(from);
     }
     _transfer(from, to, tokenId);
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
   ) public payable override {
     if(excludedList[from] == false) {
       _payTxFee(from);
     }
     safeTransferFrom(from, to, tokenId, "");
   }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public payable override {
    require(
      _isApprovedOrOwner(_msgSender(), tokenId), 
      "ERC721: transfer caller is not owner nor approved"
    );
    if(excludedList[from] == false) {
      _payTxFee(from);
    }
    _safeTransfer(from, to, tokenId, _data);
  }

  function _payTxFee(address from) internal {
    payable(from).transfer(txFeeAmount);
  }

  function getMintedInvites() public view returns( Invite[] memory){
    return mintedInvites;
}
}