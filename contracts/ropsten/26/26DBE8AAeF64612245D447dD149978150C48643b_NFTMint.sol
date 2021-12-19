// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMint is ERC721, Ownable {

	string public baseURI;
	uint256 public constant MAX_SUPPLY = 10000;
	uint256 public mintedSoFar;
	address public store;

	constructor( string memory __name, string memory __symbol, string memory __baseURI ) ERC721(__name, __symbol) {
		baseURI = __baseURI;
	}

	modifier onlyOwnerOrStore() {
		require(store == msg.sender || owner() == msg.sender,"!!! you need to point your nftmint at your store !!!");
		_;
	}

	function setBaseURI(string memory __baseURI) external onlyOwner {
		baseURI = __baseURI;
	}

	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}

	function setStore(address _store) external onlyOwner {
		store = _store;
	}

	function mint(address to) public onlyOwnerOrStore {
		require(mintedSoFar < MAX_SUPPLY, "Exceeds max supply");
		_mint(to, mintedSoFar);
		mintedSoFar += 1;
	}
}