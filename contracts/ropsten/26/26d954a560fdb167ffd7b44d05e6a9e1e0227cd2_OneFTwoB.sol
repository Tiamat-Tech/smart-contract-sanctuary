pragma solidity >= 0.5.0 < 0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract OneFTwoB is ERC721,Ownable {
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.UintSet;

  constructor (string memory name, string memory abb) ERC721(name, abb) public {
  }

  event LogTokenMinted(uint256 tokenId,string tokenURI,string date);
  event LogTokenBurnt(uint256 tokenId);
  event LogMessageAdded(uint256 tokenId, string message, uint256 messageId);

  mapping (uint256 => string) public idToDate;
  mapping (string => uint256) public dateToId;
  mapping (uint256 => EnumerableSet.UintSet) private _idToMessageSet;
  mapping (uint256 => string) public messageId;

  uint256 public lastId=0;
  uint256 public lastMess=0;

  function dateOwner(string memory date) public view returns(address) {
    return ownerOf(dateToId[date]);
  }
  function messageCount(uint256 tokenId) public view returns(uint256){
    return _idToMessageSet[tokenId].length();
  }
  function viewMessage(uint256 tokenId, uint256 index) public view returns(string memory){
    return messageId[_idToMessageSet[tokenId].at(index)];
  }
  function mintWithURI(string memory _tokenURI,string memory _date) onlyOwner public {
    _mint(owner(), lastId+1);
    _setTokenURI(lastId+1, _tokenURI);
    idToDate[lastId+1]=_date;
    dateToId[_date]=lastId+1;
    lastId=lastId+1;
    emit LogTokenMinted( lastId, _tokenURI, _date);
  }
  function burn(uint256 tokenId) onlyOwner public {
    require(_exists(tokenId));
    require(ownerOf(tokenId)==owner());
    _burn(tokenId);
    dateToId[idToDate[tokenId]]=0;
    idToDate[tokenId]="";
    emit LogTokenBurnt(tokenId);
  }
  function addMessage(uint256 tokenId, string memory message) public {
    require(msg.sender==ownerOf(tokenId));
    messageId[lastMess+1]=message;
    _idToMessageSet[tokenId].add(lastMess+1);
    lastMess=lastMess+1;
    emit LogMessageAdded(tokenId,message,lastMess);
  }
}