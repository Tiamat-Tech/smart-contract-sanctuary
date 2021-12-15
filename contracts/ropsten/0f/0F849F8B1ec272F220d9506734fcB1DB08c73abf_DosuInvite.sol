// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DosuInvite is ERC721, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  uint256 public constant MAX_INVITES_SUPPLY = 999;

  struct Invite {
    address ethAddress;
    uint256 tokenId;
  }

  event Mint(address to, uint256 tokenId);

  Invite[] internal mintedInvites;

  constructor() ERC721("Dosu Invites", "DOSU") {}

  function mint(address _to) public onlyOwner  {
    require(balanceOf(_to) >= 1, "This address already have an invite");
    require(_tokenIds.current() >= MAX_INVITES_SUPPLY, "No invites left");
    
    _tokenIds.increment();

    uint256 newInviteId = _tokenIds.current();
    _mint(_to, newInviteId);

    emit Mint(_to, newInviteId);

    Invite memory invite = Invite({tokenId: newInviteId, ethAddress: _to});
    mintedInvites.push(invite);
  }

  function getMintedInvites() public view returns( Invite[] memory){
    return mintedInvites;
}
}