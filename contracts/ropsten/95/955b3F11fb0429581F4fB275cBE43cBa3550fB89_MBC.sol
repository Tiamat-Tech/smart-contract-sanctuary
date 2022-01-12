//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transferToken(address sender,address _recipient, uint256 _amount) external returns (bool);
}

contract MBC is ERC721 {

    using SafeMath for uint256;
   
   uint256 tokenCounter = 100000;
    address public owner; 
    address public tokenAddres;

    mapping(uint256=>mapping(address=>uint256)) price;
    mapping(uint256=>address) creator;
    mapping(uint256=>string) ccid;
    string url;

    modifier isOwnerOfToken(uint256 _tokenId){
        require(_msgSender()==ownerOf(_tokenId),"NOT THE OWNER OF THE TOKEN");
        _;
    }

   
    constructor(string memory _url,address _tokenAddress) ERC721("MNBCNFT","MBC") {
        owner = _msgSender();
        tokenAddres = _tokenAddress;
        url = _url;
    }

    function getCCID(uint256 _tokenId) public view returns(string memory){
       return(ccid[_tokenId]); 
    }

     function setCCID(uint256 _tokenId,string memory _ccid) public isOwnerOfToken(_tokenId) {
        ccid[_tokenId] = _ccid;
    }

    function getPrice(uint _tokenid, address _owner) public view returns(uint256){
                return price[_tokenid][_owner];
    }

    function setPrice(uint256 _tokenId,address _owner,uint256 _amount) public isOwnerOfToken(_tokenId) {
        price[_tokenId][_owner] = _amount;
    }

    function getCreator(uint256 _tokenId) public view returns(address){
        return creator[_tokenId];
    }

    function setCreator(uint256 _tokenId, address _address) internal{
        creator[_tokenId] = _address;
    }

   function mint(string memory _ccid,uint256 _tokenValue) public returns(uint256){
            tokenCounter++;
            _mint(_msgSender(),tokenCounter);
            saveNFTData(_tokenValue, _msgSender(), tokenCounter, _ccid);
            return tokenCounter;
    }
    
    function saveNFTData(uint256 _tokenValue,address _owner,uint256 _tokenId, string memory _ccid) private {
            setCreator(_tokenId,_owner);
            setPrice(_tokenId, _owner, _tokenValue);
            setCCID(_tokenId, _ccid);
    }

    function sendToken(address from , address to , uint256 amount) private {
       IERC20(tokenAddres).transferToken(from,to,amount);
   }

    function TransferFrom(
        address from,
        address to,
        uint256 _tokenId
    ) public isOwnerOfToken(_tokenId)  {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        uint256 owner_share = share(getPrice(_tokenId, from),2);
        uint256 token_owner_share = getPrice(_tokenId, from) - owner_share;
        sendToken(to,owner,owner_share);
        sendToken(to, from, token_owner_share);
        _transfer(from, to, _tokenId);
    }


    function share(uint256 _amount , uint256 _percentage) internal pure returns(uint256){
            return(_amount*_percentage/100);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override isOwnerOfToken(tokenId) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        uint256 owner_share = share(getPrice(tokenId, from),2);
        uint256 token_owner_share = getPrice(tokenId, from) - owner_share;
        sendToken(to,owner,owner_share);
        sendToken(to, from, token_owner_share);
        _safeTransfer(from, to, tokenId, _data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override isOwnerOfToken(tokenId){
         uint256 owner_share = share(getPrice(tokenId, from),2);
        uint256 token_owner_share = getPrice(tokenId, from) - owner_share;
        sendToken(to,owner,owner_share);
        sendToken(to, from, token_owner_share);
        safeTransferFrom(from, to, tokenId, "");
    }

}