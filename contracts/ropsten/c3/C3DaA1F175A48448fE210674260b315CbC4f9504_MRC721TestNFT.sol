// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MRC721.sol";

contract MRC721TestNFT is MRC721{

	constructor(
    ) MRC721(
    	"MRC721 Test", 
    	"MRC",
        "https://mmac-meta-martian.communitynftproject.io/"
    ){
    	_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    	_setupRole(MINTER_ROLE, msg.sender);
    }

    function mintPublic(address to, uint256 id) public{
        _mint(to, totalSupply());
    }
}