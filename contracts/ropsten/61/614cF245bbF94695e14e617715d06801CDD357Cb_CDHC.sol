// SPDX-License-Identifier: None

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//..............................................................................................
//.DDDDDDDDD....iiii..........cckk.......kHHH...HHHH............................dddd............
//.DDDDDDDDDD...iiii..........cckk.......kHHH...HHHH............................dddd............
//.DDDDDDDDDDD................cckk.......kHHH...HHHH............................dddd............
//.DDDD...DDDD..iiii..cccccc..cckk..kkkk.kHHH...HHHH...eeeeee....aaaaaa....ddddddddd.dssssss....
//.DDDD....DDDD.iiii.cccccccc.cckk.kkkk..kHHH...HHHH..Heeeeeee..eaaaaaaa..adddddddddddsssssss...
//.DDDD....DDDD.iiiiicccc.cccccckkkkkk...kHHHHHHHHHH.HHee.eeee.eeaa.aaaaaaaddd.dddddddss.ssss...
//.DDDD....DDDD.iiiiiccc..ccc.cckkkkk....kHHHHHHHHHH.HHee..eeee....aaaaaaaadd...ddddddsss.......
//.DDDD....DDDD.iiiiiccc......cckkkkkk...kHHHHHHHHHH.HHeeeeeeee.eaaaaaaaaaadd...dddd.dsssss.....
//.DDDD....DDDD.iiiiiccc......cckkkkkk...kHHH...HHHH.HHeeeeeeeeeeaaaaaaaaaadd...dddd..sssssss...
//.DDDD...DDDDD.iiiiiccc..ccc.cckkkkkkk..kHHH...HHHH.HHee......eeaa.aaaaaaadd...dddd......ssss..
//.DDDDDDDDDDD..iiiiicccc.cccccckk.kkkk..kHHH...HHHH.HHee..eeeeeeaa.aaaaaaaddd.dddddddss..ssss..
//.DDDDDDDDDD...iiii.ccccccccccckk..kkkk.kHHH...HHHH..Heeeeeee.eeaaaaaaaa.adddddddddddsssssss...
//.DDDDDDDDD....iiii..cccccc..cckk..kkkk.kHHH...HHHH...eeeeee...eaaaaaaaa..ddddddddd..ssssss....
//..............................................................................................
//Twitter @devDwarf

contract CDHC is Ownable, ERC721 {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  uint256 public mintPrice = 0;
  uint256 public mintLimit = 1;

  string public baseExtension = ".json";
  

  uint256 public maxSupply = 45;
  Counters.Counter private _tokenIdCounter;

  bool public publicSaleState = false;

  string public baseURI;

  address private deployer;

  constructor() ERC721("Crypto DickHeads Contest", "CDHC") { 
    deployer = msg.sender;
  }
  

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function setBaseURI(string calldata newBaseUri) external onlyOwner {
    baseURI = newBaseUri;
  }
  
  function changeStatePublicSale() public onlyOwner returns(bool) {
    publicSaleState = !publicSaleState;
    return publicSaleState;
  }

  function mint(uint numberOfTokens) external payable {
    require(publicSaleState, "Sale is not active");
    require(numberOfTokens <= mintLimit, "Too many tokens for one transaction");
    require(msg.value >= mintPrice.mul(numberOfTokens), "Insufficient payment");

    mintInternal(msg.sender, numberOfTokens);
  }


  function mintInternal(address wallet, uint amount) internal {

    uint currentTokenSupply = _tokenIdCounter.current();
    require(currentTokenSupply.add(amount) <= maxSupply, "Not enough tokens left");

    
    for(uint i = 0; i< amount; i++){
    currentTokenSupply++;
    _safeMint(wallet, currentTokenSupply);
    _tokenIdCounter.increment();
    }
  }



  function reserve(uint256 numberOfTokens) external onlyOwner {
    mintInternal(msg.sender, numberOfTokens);
  }

  function totalSupply() public view returns (uint){
    return _tokenIdCounter.current();
  }
  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
  
  function withdraw() public onlyOwner {
    require(address(this).balance > 0, "No balance to withdraw");
    payable(deployer).transfer(address(this).balance); 
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, uint2str(tokenId), baseExtension))
        : "";
  }

}