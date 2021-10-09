// SPDX-License-Identifier: MIT

// ______  __  __   ______       _____    __  __   _____    ______
// /\__  _\/\ \_\ \ /\  ___\     /\  __-. /\ \/\ \ /\  __-. /\  ___\
// \/_/\ \/\ \  __ \\ \  __\     \ \ \/\ \\ \ \_\ \\ \ \/\ \\ \  __\
//   \ \_\ \ \_\ \_\\ \_____\    \ \____- \ \_____\\ \____- \ \_____\
//    \/_/  \/_/\/_/ \/_____/     \/____/  \/_____/ \/____/  \/_____/
//

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NumbersDNAFactory.sol";
interface theDudes
{
    function ownerOf (uint256 tokenid) external view returns (address);
    function dudes (uint256 tokenid) external view returns (string memory);
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
}
contract Numbers is ERC721Enumerable, NumbersDNAFactory, Ownable {
  using SafeMath for uint256;
  using SafeMath for uint8;
  using SafeMathUint for uint256;
  using Strings for uint256;

  uint public maxNumbers = 2050;
  uint public maxNumbersPerPurchase = 10;
  uint256 public price = 30000000000000000; // 0.030 Ether
  
  address public thedudesaddress = 0x262A155086361a694cF5a4E6277230b0318A8dfd; 
  theDudes thedudescontract = theDudes(thedudesaddress);  

  bool public isSaleActive = true;//cchaange to false
  bool public isClaimActive = true;//cchaange to false
  string public baseURI;
  
  mapping(uint256 => bool) public claimedTokenIds; //the Dudes tokenId
  mapping (uint => string) public numbers;

  address constant private creator = 0xB3F764FC0E16Ed716B601213fC2262B54BF0d1EC;

  constructor (uint _maxNumbers, uint _maxNumbersPerPurchase) ERC721("numbers", "num") {
    maxNumbers = _maxNumbers;
    maxNumbersPerPurchase = _maxNumbersPerPurchase;
    _mint(creator, 1, 873281);
  }
  
  //for dudes claimall should work
 function claimAll(address _owner, uint _salt) public {
    require(isClaimActive, "Claim is not active yet.");
    require(!allClaimed(_owner), "All your tokens are claimed.");
    int256[] memory tokenIds = claimableOf(_owner);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (tokenIds[i] != -1) {
        claim(uint256(tokenIds[i]),_salt);
      }
    }
  }

  function claim(uint256 _tokenId, uint _salt) internal {
    require(isSaleActive, "Sale is not active!" );
    require(1 <= maxNumbersPerPurchase, 'You can get no more than 10 Numbers at a time');
    require(totalSupply().add(1) <= maxNumbers, "Sorry too many numbers!");
    require(thedudescontract.ownerOf(_tokenId) == msg.sender, "Not the owner of this dudes.");
    claimedTokenIds[_tokenId] = true;
    _mint(msg.sender, 1, _salt);
  }

  function _claim(address _to, uint256 _numnumbers, uint _salt) internal {
      uint256 mintIndex = totalSupply();
          if (totalSupply() < maxNumbers) {
            for (uint256 i = 0; i < _numnumbers; i++) {
               string memory numId = string(abi.encodePacked(_getDNA(_salt * i)));
                numbers[mintIndex] = numId;
                _safeMint(_to, mintIndex);
           }
            }
  }

 function claimableOf(address _owner) public view returns (int256[] memory) {
    uint256[] memory tokenIds = thedudescontract.tokensOfOwner(_owner);
    int256[] memory claimableTokenIds = new int256[](tokenIds.length);
    uint256 index = 0;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      uint256 tokenId = tokenIds[i];
      claimableTokenIds[i] = -1;
      if (thedudescontract.ownerOf(tokenId) == _owner) {
        if (!claimedTokenIds[tokenId]) {
          claimableTokenIds[index] = tokenId.toInt256Safe();
          index++;
        }
      }
    }
    return claimableTokenIds;
  }

  function allClaimed(address _owner) public view returns (bool) {
    int256[] memory tokenIds = claimableOf(_owner);
    bool isAllClaimed = true;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (tokenIds[i] != -1) {
        isAllClaimed = false;
      }
    }
    return isAllClaimed;
  }


//regular sale
 function mint(uint256 _numnumbers, uint _salt) public payable {
    require(isSaleActive, "Sale is not active!" );
    require(_numnumbers <= maxNumbersPerPurchase, 'You can get no more than 10 Numbers at a time');
    require(totalSupply().add(_numnumbers) <= maxNumbers, "Sorry too many numbers!");
    require(msg.value >= price.mul(_numnumbers), "Ether value sent is not correct!");
    _mint(msg.sender, _numnumbers, _salt);
  }

  function _mint(address _to, uint256 _numnumbers, uint _salt) internal {
    for (uint256 i = 0; i < _numnumbers; i++) {
      uint256 mintIndex = totalSupply();

      string memory numId = _getDNA(_salt * i);
      numbers[mintIndex] = numId;

      _safeMint(_to, mintIndex);
    }
  }

  function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 tokenCount = balanceOf(_owner);
    if (tokenCount == 0) {
      return new uint256[](0);
    } else {
      uint256[] memory result = new uint256[](tokenCount);
      uint256 index;
      for (index = 0; index < tokenCount; index++) {
        result[index] = tokenOfOwnerByIndex(_owner, index);
      }
      return result;
    }
  }

  function setPrice(uint256 _newPrice) public onlyOwner {
    price = _newPrice;
  }

  function setIsSaleActive(bool _isSaleActive) public onlyOwner {
    isSaleActive = _isSaleActive;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }
  
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
    return string(abi.encodePacked(_baseURI(), "/", _tokenId.toString(),"-", numbers[_tokenId],".json"));
  }   

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }
}

// File: contracts\SafeMathUint.sol

pragma solidity ^0.8.0;
/**
 * @title SafeMathUint
 * @dev Math operations with safety checks that revert on error
 */
library SafeMathUint {
  function toInt256Safe(uint256 a) internal pure returns (int256) {
    int256 b = int256(a);
    require(b >= 0);
    return b;
  }

}