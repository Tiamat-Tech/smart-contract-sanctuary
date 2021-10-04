// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract NFTDemo is ERC721URIStorage, Ownable {
	uint256 private _tokenId;
	string private _tokenBaseURI;

	constructor (string memory name, string memory symbol) ERC721(name, symbol) Ownable() {

	}

	function mint(address to) public onlyOwner {
		_tokenId ++;
		_safeMint(to, _tokenId);
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
		string memory baseURI = _baseURI();
		string memory uriString = string(abi.encodePacked(baseURI, tokenId));
		return uriString;
	}

	function setBaseURI(string calldata baseURI) public onlyOwner {
		_tokenBaseURI = baseURI;
	}

	function _baseURI() override internal view returns (string memory) {
        return _tokenBaseURI;
    }
}