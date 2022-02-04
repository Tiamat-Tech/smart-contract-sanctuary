// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ClubVirtual is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public _contractOwner;

    mapping(uint256=>string) private tokenURI;

    constructor() ERC1155("http://localhost:8000/") {
       _contractOwner = _msgSender();
    }

    function mint(address _address,uint256 _numberoftokens, string memory _tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        setURI(newItemId,_tokenURI);
        _mint(_address, newItemId,_numberoftokens,"");

        return newItemId;
    }

    function setURI(uint256 tokenId,string memory _tokenURI) internal {
        tokenURI[tokenId] = _tokenURI;
    }

    function getURI(uint256 _tokenId) public view returns(string memory){
        string memory uri = tokenURI[_tokenId];
        return(uri);
    }

    function transferamount(address creator,address admin,address owner,uint256 amount,uint256 adminpersent, uint256 royaltypersent) public payable{   
      address payable _creator = payable(creator);
      address payable _admin = payable(admin);
      address payable _owner = payable(owner);
      // uint256 adn=adminpersent/10000000000;
      uint256 ownerpercent=(1000000000000-adminpersent-royaltypersent);
      uint256 creatoramount = (amount * royaltypersent)/1000000000000;
      uint256 adminamount = (amount*adminpersent)/1000000000000;
      uint256 owneramount = (amount*ownerpercent)/1000000000000;
    
      _creator.transfer(creatoramount);
      _admin.transfer(adminamount);
      _owner.transfer(owneramount);
  }

  function transferFrom(address from , address to , uint256 tokenId, uint256 amountoftoken) public {
      _safeTransferFrom(from,to,tokenId,amountoftoken,""); 
  }

  function getTokenId() public view returns(uint256){
       uint256 newItemId = _tokenIds.current();
       return(newItemId);
  }

}