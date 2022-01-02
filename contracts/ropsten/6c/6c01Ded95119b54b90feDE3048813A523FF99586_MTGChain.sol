// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract MTGChain is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;
	using SafeMath for uint256;
	
	// Owners
	address private owner1 = 0x8f2d2822D2559aAa7a2c74CD6c9C99492E705bD1;
	
	// Token Info
	uint256 public constant MAX_SUPPLY = 10100;

    // Base URI
    string private _baseURIextended;
		
	// Offsets
	uint256 public o = 0;
	
	event OnTokenDropped(uint256 supply);
	
	// Modifiers
	modifier isRealUser() {
		require(msg.sender == tx.origin, "Sorry, you do not have the permission todo that.");
		_;
	}
	modifier isOwner() {
        require(msg.sender == owner1, "You are not an owner");
        _;
    }
	
    constructor()
        ERC721('MTG Chain', 'MTGC')
    {
		
	}
	
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
	
	function getTotalSupply() public view returns (uint256) {
		return totalSupply();
	}
	
	function getTokenByOwner(address _owner) public view returns (uint256[] memory) {
		uint256 tokenCount = balanceOf(_owner);
		uint256[] memory tokenIds = new uint256[](tokenCount);
		for (uint256 i; i < tokenCount; i++) {
			tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
		}
		return tokenIds;
	}
	
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
		
		if(tokenId < MAX_SUPPLY) {
			uint256 offset = tokenId.add(MAX_SUPPLY.sub(o)).mod(MAX_SUPPLY);
			
			return string(abi.encodePacked(_baseURI(), offset.toString(), ".json"));
		} else {
			return "ERC721Metadata: URI query for nonexistent token - Invalid token ID";
		}
	}
  
	function reserveToken(uint256 num) public onlyOwner() {
		require(totalSupply().add(num) <= MAX_SUPPLY, "Exceeding max supply");
		_mint(num, msg.sender);
		emit OnTokenDropped(totalSupply());
	}
	
	function airdropToken(uint256 num, address recipient) public onlyOwner() {
		require(totalSupply().add(num) <= MAX_SUPPLY, "Exceeding max supply");
		_mint(num, recipient);
		emit OnTokenDropped(totalSupply());
	}
	
	function _mint(uint256 num, address recipient) internal {
		uint256 supply = totalSupply();
		for (uint256 i = 0; i < num; i++) {
			_safeMint(recipient, supply + i);
		}
	}
	
	function airdropTokenToMultipleRecipient(address[] memory recipients) external onlyOwner() {
		require(totalSupply().add(recipients.length) <= MAX_SUPPLY, "Exceeding max supply");
		for (uint256 i = 0; i < recipients.length; i++) {
			airdropToken(1, recipients[i]);
		}
	}
	
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 tokenId
	) internal override(ERC721, ERC721Enumerable) {
		super._beforeTokenTransfer(from, to, tokenId);
	}
	
	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(ERC721, ERC721Enumerable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}
	
	fallback() external payable {
		revert();
	}
	
}