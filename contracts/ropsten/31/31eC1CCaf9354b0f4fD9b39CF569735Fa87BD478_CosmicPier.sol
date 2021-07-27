// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./RBAC.sol";

contract CosmicPier is ERC721URIStorage, RBAC {
	using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

	event WithdrawEth(address indexed _buyer, uint256 _ethWei);

	uint256 public maxSupply;
	uint256 private _totalSupply;
	uint256 private serialNumber;
	RBAC.RolesManager private rolesManager;

    constructor(address _owner, uint256 _maxSupply) 
	ERC721("Cosmic Pier", "Pier") 
	RBAC(_owner)
	{
		maxSupply = _maxSupply;
		_totalSupply = 0;
    }

	function decimals() public view virtual  returns (uint8) {
        return 0;
    }

	function totalSupply() external view  returns (uint256)
	{
		return _totalSupply;
	}

	function mint(address receiver) external RBAC.onlyRole("mint") returns (uint256)
	{
		require (maxSupply > 0 && _totalSupply <= maxSupply, "MAX SUPPLY LIMITED");
        uint256 tokenID = _tokenIds.current();

		_safeMint(receiver, tokenID);

		_tokenIds.increment();
		_totalSupply += 1;

		return tokenID;
	}

	function mintNft(address receiver, string memory tokenURI) external RBAC.onlyRole("mint") returns (uint256) {
         uint256 tokenID = _tokenIds.current();

        _safeMint(receiver, tokenID);

        _setTokenURI(tokenID, tokenURI);

		_tokenIds.increment();
		_totalSupply += 1;

        return tokenID;
    }

	function burn(uint256 _tokenID) external RBAC.onlyRole("burn")
	{
		require (_totalSupply > 0, "No tokens to  burn");

		_burn(_tokenID);
		_totalSupply -= 1;
	} 

	receive() external virtual payable { } 

    fallback() external virtual payable {  }

	function withdrawEth(uint256 ethValue) external onlyOwner returns(bool)
    {
        require(address(this).balance >= ethValue, "the contract hasn't engogh eth to transfer");
        payable(address(msg.sender)).transfer(ethValue);

        emit WithdrawEth(msg.sender, ethValue);

        return true;
    }
}