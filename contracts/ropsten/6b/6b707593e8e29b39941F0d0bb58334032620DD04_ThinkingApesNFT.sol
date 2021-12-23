// SPDX-License-Identifier: MIT

/*

 _____   _ _          _ _               _                  _   _ _____ _____ 
|_   ___| (_) __ ___ | (_) __ _ _ __   / \   __ _ ___  ___| | / |___  |_   _|
  | |/ _` | |/ _` \ \| | |/ _` | '_ \ / _ \ / _` / _ \|__ | |/  |  _| | | |  
  | | | | | | | | |>   | | | | | |_) / ___ | (_| \__  / __|  /| | |_  | | |  
  |_|_| |_|_|_| |_/_/|_|_|_| |_| .__/_/   \_\__, |___/\___|_/ |_|   |_| |_|  
                                \___|          |_|                           

	Be the first to build your dreams - ThinkingApesNFT 2021-2022
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract ThinkingApesNFT is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;
	using SafeMath for uint256;
	
	// Token Info
	uint256 public constant PRICE = .08 ether;
	uint256 public constant MAX_SUPPLY = 10000;
	uint256 public constant MAX_VOLUME_MITABLE = 9950;
	uint256 public revealTimeStamp = block.timestamp + (86400 * 7);
    
    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURIextended;
	string private _preRevealURI;
	
	// AllowList
	mapping(address => bool) private _allowList; 
	mapping(address => bool) private _blackList;
	
	// PreSale - PublicSales
	bool private _isPreSaleActive = false;
	bool private _isPublicSaleActive = false;
	
	// Owners
	address private owner1 = 0x8f2d2822D2559aAa7a2c74CD6c9C99492E705bD1;
	address private owner2 = 0x8f2d2822D2559aAa7a2c74CD6c9C99492E705bD1;
	address private owner3 = 0x8f2d2822D2559aAa7a2c74CD6c9C99492E705bD1;
	address private owner4 = 0x8f2d2822D2559aAa7a2c74CD6c9C99492E705bD1;
	
	// Offsets
	uint256 public offsetIndex = 0;
	
	// Modifiers
	modifier isRealUser() {
		require(msg.sender == tx.origin, "Sorry, you do not have the permission todo that.");
		_;
	}
	modifier isOwner() {
        require(msg.sender == owner1 || msg.sender == owner2 || msg.sender == owner3 || msg.sender == owner4, "You are not an owner");
        _;
    }
	
	// Events
	event PreSaleStarted();
	event PreSaleStopped();
	event PublicSaleStarted();
	event PublicSaleStopped();
	event OnTokenMinted(uint256 supply);
	
    constructor()
        ERC721('ThinkingApesNFT', 'TA')
    {
		
	}
	
	function addToAllowList(address[] calldata addresses) external onlyOwner() {
		for (uint256 i = 0; i < addresses.length; i++) {
		  require(addresses[i] != address(0), "Null address");
		  _allowList[addresses[i]] = true;
		}
	}

	function removeFromAllowList(address[] calldata addresses) external onlyOwner() {
		for (uint256 i = 0; i < addresses.length; i++) {
		  require(addresses[i] != address(0), "Null address");
		  _allowList[addresses[i]] = false;
		}
	}
	
	function isAddressAllowed(address addr) external view returns (bool) {
		return _allowList[addr];
	}

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }
    
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
	
	function setPreRevealURI(string memory preRevealURI) external onlyOwner() {
		_preRevealURI = preRevealURI;
	}
	
	function setRevealTimestamp(uint256 newTimeStamp) external onlyOwner {
		revealTimeStamp = newTimeStamp;
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
	
	function startPreSale() public onlyOwner() {
		_isPreSaleActive = true;
		emit PreSaleStarted();
	}

	function pausePreSale() public onlyOwner() {
		_isPreSaleActive = false;
		emit PreSaleStopped();
	}
	
	function isPreSaleActive() public view returns (bool) {
		return _isPreSaleActive;
	}
	
	function startPublicSale() public onlyOwner() {
		_isPublicSaleActive = true;
		emit PublicSaleStarted();
	}

	function pausePublicSale() public onlyOwner() {
		_isPublicSaleActive = false;
		emit PublicSaleStopped();
	}
	
	function isPublicSaleActive() public view returns (bool) {
		return _isPublicSaleActive;
	}
	
	function withdraw() public isOwner {
		uint256 _each = address(this).balance / 4;
		require(payable(owner1).send(_each), "Something went wrong while sending transaction.");
		require(payable(owner2).send(_each), "Something went wrong while sending transaction.");
		require(payable(owner3).send(_each), "Something went wrong while sending transaction.");
		require(payable(owner4).send(_each), "Something went wrong while sending transaction.");
	}
	
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
		
		if (totalSupply() >= MAX_SUPPLY || block.timestamp >= revealTimeStamp) {
			if(tokenId < MAX_SUPPLY) {
				uint256 offset = tokenId.add(MAX_SUPPLY.sub(offsetIndex)).mod(MAX_SUPPLY);
				
				return string(abi.encodePacked(_baseURI(), offset.toString(), ".json"));
			} else {
				return "ERC721Metadata: URI query for nonexistent token - Invalid token ID";
			}
		} else {
			return _preRevealURI;
		}
	}
	
	function mintPresale(uint8 TOKENS_TO_MINT) public payable isRealUser {
		require(_isPreSaleActive, "Sorry, pre-sales is not active yet.");
		require(totalSupply().add(TOKENS_TO_MINT) <= MAX_VOLUME_MITABLE, "Exceeding max supply");
		require(_allowList[msg.sender], "Sorry, you are not whitelisted.");
		require(TOKENS_TO_MINT <= 2, "Sorry, you are trying to mint too many tokens at one time");
		require(TOKENS_TO_MINT > 0, "You need to mint at least one token");
		require(PRICE*TOKENS_TO_MINT <= msg.value, "Sorry, you did not sent the required amount of ETH");
		_allowList[msg.sender] = false;
		_mint(TOKENS_TO_MINT, msg.sender);
		emit OnTokenMinted(totalSupply());
	}
	
	function mintPublic(uint8 TOKENS_TO_MINT) public payable isRealUser {
		require(_isPublicSaleActive, "Sorry, public-sales are not active yet.");
		require(totalSupply().add(TOKENS_TO_MINT) <= MAX_VOLUME_MITABLE, "Exceeding max supply");
		require(TOKENS_TO_MINT <= 10, "Sorry, you are trying to mint too many tokens at one time");
		require(TOKENS_TO_MINT > 0, "You need to mint at least one token");
		require(PRICE*TOKENS_TO_MINT <= msg.value, "Sorry, you did not sent the required amount of ETH");
		_mint(TOKENS_TO_MINT, msg.sender);
		emit OnTokenMinted(totalSupply());
	}
    
	function reserveToken(uint256 num) public onlyOwner() {
		require(totalSupply().add(num) <= MAX_SUPPLY, "Exceeding max supply");
		_mint(num, msg.sender);
		emit OnTokenMinted(totalSupply());
	}
	
	function airdropToken(uint256 num, address recipient) public onlyOwner() {
		require(totalSupply().add(num) <= MAX_SUPPLY, "Exceeding max supply");
		_mint(num, recipient);
		emit OnTokenMinted(totalSupply());
	}
	
	function airdropTokenToMultipleRecipient(address[] memory recipients) external onlyOwner() {
		require(totalSupply().add(recipients.length) <= MAX_SUPPLY, "Exceeding max supply");
		for (uint256 i = 0; i < recipients.length; i++) {
			airdropToken(1, recipients[i]);
		}
	}
	
	function _mint(uint256 num, address recipient) internal {
		uint256 supply = totalSupply();
		for (uint256 i = 0; i < num; i++) {
			_safeMint(recipient, supply + i);
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
}