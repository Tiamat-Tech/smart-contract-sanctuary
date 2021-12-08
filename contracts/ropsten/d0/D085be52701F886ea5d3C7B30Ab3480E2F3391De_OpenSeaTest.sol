// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OpenSeaTest is ERC721{
  using Strings for uint256;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  string public baseUri = "https://graffitimansionlabs.mypinata.cloud/ipfs/QmbmVcWH7ngspWxaQ7fcFr7mgZG5topTGA3Sjx79kzRt9f/"; 
  string public baseExtension = ".json"; 
  
  constructor() ERC721("NFT", "NFTT"){}                

  function mint(uint amount) external{
    _mintToken(msg.sender, amount);
  }

  function _mintToken(address to, uint amount) private {
    uint id;
    for(uint i = 0; i < amount; i++){
      _tokenIds.increment();
      id = _tokenIds.current();
      _mint(to, id);
    }
  }

  function setBaseExtension(string memory newBaseExtension) external  {
    baseExtension = newBaseExtension;
  }

  function setBaseUri(string memory newBaseUri) external {
    baseUri = newBaseUri;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory _tokenURI = "Token with that ID does not exist.";
    if (_exists(tokenId)){
      _tokenURI = string(abi.encodePacked(baseUri, tokenId.toString(),  baseExtension));
    }
    return _tokenURI;
  }
  
  function totalSupply() public view returns(uint){
    return _tokenIds.current();
  }

}