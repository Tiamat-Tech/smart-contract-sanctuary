//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptoBBC is ERC721, Ownable {
    using Strings for uint256;

    struct Metadata {
        address contractAddress;
        uint256 tokenId;
        string uri;
    }
    mapping (uint256 => Metadata) public tokenMap;

    uint256 private tokenCounter;
    constructor() ERC721("CryptoBBC", "CBBC") {
        tokenCounter = 0;
    }

    function mint() external {
      _safeMint(_msgSender(), tokenCounter);
      tokenCounter = tokenCounter + 1;
    }

    function mintAndLink(uint256 _tokenId,
            address _adContractAddress, uint256 _adTokenId) external {
      _safeMint(_msgSender(), tokenCounter);
      tokenCounter = tokenCounter + 1;
      setBillboardToken(_tokenId, _adContractAddress, _adTokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenMap[tokenId].uri)) : "";
    }

    function setBillboardToken(uint256 _tokenId,
            address _adContractAddress, uint256 _adTokenId) public {
        require(_isOwnerOfAd(_msgSender(), _adContractAddress, _adTokenId), "CryptoBBC: Caller is not owner of Ad Token.");
        tokenMap[_tokenId].tokenId = _adTokenId;
        tokenMap[_tokenId].contractAddress = _adContractAddress;        
        tokenMap[_tokenId].uri = _retrieveAdURI(_adContractAddress, _adTokenId);        
    }

    function transfer(address addr, uint256 _tokenId) public {
      _transfer(msg.sender, addr, _tokenId);
    }

     function _isOwnerOfAd(address spender, address _adContractAddress, uint256 adTokenId) private view returns (bool) {
        ERC721 adContract = ERC721(_adContractAddress);
        address owner = adContract.ownerOf(adTokenId);
        return spender == owner;
    }

    function _retrieveAdURI(address addr, uint256 _tokenId) private view returns (string memory) {
      ERC721 adContract = ERC721(addr);
      return adContract.tokenURI(_tokenId);
    }

    function _baseURI() override internal view virtual returns (string memory) {
        return "Test Base URI"; //
    }
}