// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PolishedNFT is ERC721, Ownable {
	using SafeMath for uint256;
	using Counters for Counters.Counter;

	Counters.Counter private _tokenId;
	uint256 public constant MAX_TOKENS = 10;
	uint256 public constant MAX_TOKENS_PER_PURCHASE = 2;
	uint256 public constant TOKEN_PRICE = 5000000000000000;
	string public constant BASE_URI = "ipfs://bafybeibrjnnnawzugmmdz6mkdy5nui4vu4ffrczgriakinekpnh7ei7ale/";
	string public constant PROVENANCE_HASH = "ccecdc8b2603c0334751e265a10d5b9f56c720faf3824d93a1cff908ef339474";

	constructor() ERC721("PolishedNFT", "POLISHED") {}

	function _baseURI() internal pure override returns (string memory) {
		return BASE_URI;
	}

	function _mintItem(address to) internal {
		_safeMint(to, totalSupply());
		_tokenId.increment();
	}

	function mintItems(uint256 amount) public payable {
		uint256 total = totalSupply();

		require(total.add(amount) <= MAX_TOKENS);
		require(amount <= MAX_TOKENS_PER_PURCHASE);
		require(TOKEN_PRICE.mul(amount) <= msg.value);

		for (uint256 i = 0; i < amount; i++) {
			_mintItem(msg.sender);
		}
	}

	function reserve(uint256 amount) public onlyOwner {
		uint256 total = totalSupply();

		require(total.add(amount) <= MAX_TOKENS);

		for (uint256 i = 0; i < amount; i++) {
			_mintItem(msg.sender);
		}
	}

	function withdraw() public onlyOwner {
		uint256 balance = address(this).balance;
		payable(msg.sender).transfer(balance);
	}

	function totalSupply() public view returns (uint256) {
		return _tokenId.current();
	}
}