//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MBC is ERC721 {
   
   uint256 tokenId = 100000;
    address public owner; 

    mapping(uint256=>mapping(address=>uint256)) price;
    mapping(uint256=>address) creator;
    mapping(uint256=>string) ccid;
    string url;

   
    constructor(string memory _url) ERC721("MNBCNFT","MBC") {
        owner = _msgSender();
        url = _url;
    }

    function getCCID(uint256 _tokenId) public view returns(string memory){
       return(ccid[_tokenId]); 
    }

     function setCCID(uint256 _tokenId,string memory _ccid) public {
        ccid[_tokenId] = _ccid;
    }

    function getPrice(uint _tokenid, address _owner) public view returns(uint256){
                return price[_tokenid][_owner];
    }

    function setPrice(uint256 _tokenId,address _owner,uint256 _amount) public {
         require(_msgSender()==_owner,"Caller is not the Owner of the token");
        price[_tokenId][_owner] = _amount;
    }

    function getCreator(uint256 _tokenId) public view returns(address){
        return creator[_tokenId];
    }

    function setCreator(uint256 _tokenId, address _address) internal{
        creator[_tokenId] = _address;
    }

   function mint(string memory _ccid,uint256 _tokenValue) public returns(uint256){
            tokenId++;
            _mint(_msgSender(),tokenId);
            saveNFTData(_tokenValue, _msgSender(), tokenId, _ccid);
            return tokenId;
    }
    
    function saveNFTData(uint256 _tokenValue,address _owner,uint256 _tokenId, string memory _ccid) private {
            setCreator(_tokenId,_owner);
            setPrice(_tokenId, _owner, _tokenValue);
            setCCID(_tokenId, _ccid);
    }

    function safeTransferFrom(
       address from,
        address to,
        uint256 _tokenId
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _transfer(from, to, _tokenId);
    }

}