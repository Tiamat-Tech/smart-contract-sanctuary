//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyToken is
	ERC721,
	ERC721URIStorage,
	Ownable,
	ERC721Pausable,
	ERC721Enumerable,
	ReentrancyGuard
{
	using Counters for Counters.Counter;

	event Mint(address indexed _to, uint256 indexed _tokenId);
	Counters.Counter private _tokenIdCounter;
	string public baseURI;
	struct TokenInfo {
		//Order Id
		uint256 id;
		//NFT Price
		uint256 price;
		//NFT Owner address
		address nftAddress;
		//NFT uri
		string uri;
		//NFT sale
		bool sale;
	}
	mapping(uint256 => TokenInfo) private _tokenInfo;
	address[] public _admins;

	constructor() ERC721("Cherry", "CH") {
		_admins.push(msg.sender);
		setBaseURI("");
		_pause();
	}

	//*** NFT BASIC FUNCTIONS ***//


	// function to add new admin
	function addToAdmins(address _address) public {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");
		
		bool _isExist = checkArray(_address);
		if (!_isExist) {
		_admins.push(_address);
		}
	}

	// function to get all admin wallet address
	function getAdminList() external view returns (address [] memory) {
		return _admins;
	}

	// function to check if the address is admin
	function checkArray(address _address) internal view returns (bool) {
		bool _exist = false;
		for (uint i = 0; i < _admins.length; i++) {
			if (_admins[i] == _address) {
				_exist = true;
			}
		}

		return _exist;
	}

	// function to mint token
	function mintToken(string memory _uri, uint256 _price) public {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");

		uint256 _tokenId = _tokenIdCounter.current();
		_safeMint(_msgSender(), _tokenId);
		_tokenInfo[_tokenId].id = _tokenId;
		_tokenInfo[_tokenId].nftAddress = _msgSender();
		_tokenInfo[_tokenId].price = _price;
		setTokenURI(_tokenId, _uri);
		_tokenIdCounter.increment();
		emit Mint(_msgSender(), _tokenId);
		return;
	}

	// function to check possible transfer
	function transferCheck(uint256 _tokenId, uint _price) public view {
		uint256 price = _tokenInfo[_tokenId].price;
		require(price > 0, "This token is not for sale.");
		require(_price == price, "Incorrect price of the NFT.");
	}

	// function to transfer token
	function transferToken(address _address, uint256 _tokenId) public payable {
		uint256 price = _tokenInfo[_tokenId].price;
		require(price > 0, "This token is not for sale.");
		require(msg.value == price, "Incorrect price of the NFT.");
		_tokenInfo[_tokenId].price = 0;
		address seller = ownerOf(_tokenId);
		_transfer(seller, _address, _tokenId);
		(bool success, ) = seller.call{value: price}("");
		require(success, "TransferHelper: Transfer was failed.");
	}

	function _burn(uint256 _tokenId)
		internal
		override(ERC721, ERC721URIStorage)
	{
		super._burn(_tokenId);
	}

	function unPause() public {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");
		_unpause();
	}

	function pause() public {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");
		_pause();
	}

	function setTokenURI(uint256 _tokenId, string memory _tokenURI)
		internal
		returns (bool)
	{
		_setTokenURI(_tokenId, _tokenURI);
		_tokenInfo[_tokenId].uri = _tokenURI;
		return true;
	}

	function _setTokenInfo(uint256 _tokenId, TokenInfo memory _info) private {
		require(_exists(_tokenId));
		require(ownerOf(_tokenId) == _msgSender());
		_tokenInfo[_tokenId] = _info;
	}

	function setTokenSale(
		uint256 _tokenId,
		bool _sale,
		uint256 _price
	) public {
		require(
			_exists(_tokenId),
			"ERC721Metadata: Sale set of nonexistent token."
		);
		require(_price > 0);
		require(ownerOf(_tokenId) == _msgSender());
		_tokenInfo[_tokenId].sale = _sale;
		_tokenInfo[_tokenId].price = _price;
	}

	function setBaseURI(string memory _newBaseURI) public virtual {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");
		baseURI = _newBaseURI;
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 tokenId
	) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
		super._beforeTokenTransfer(from, to, tokenId);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		virtual
		override(ERC721, ERC721Enumerable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	//*** NFT VIEW FUNCTIONS ***//

	function _totalSupply() internal view returns (uint256) {
		return _tokenIdCounter.current();
	}

	function tokenURI(uint256 _tokenId)
		public
		view
		override(ERC721, ERC721URIStorage)
		returns (string memory)
	{
		return super.tokenURI(_tokenId);
	}

	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}

	function tokenPrice(uint256 _tokenId)
		public
		view
		virtual
		returns (uint256)
	{
		require(
			_exists(_tokenId),
			"ERC721Metadata: Price query for nonexistent token."
		);
		return _tokenInfo[_tokenId].price;
	}

  function isExist(uint256 _tokenId) view public returns (bool) {
    bool _exist = _exists(_tokenId);
    return _exist;
  }

	function withdraw() public {
		bool _exist = checkArray(msg.sender);
		require(_exist, "Permission denied: caller is not the admin.");
		
		(bool success, ) = msg.sender.call{value: address(this).balance}("");
		require(success, "Failed to withdraw.");
	}
}