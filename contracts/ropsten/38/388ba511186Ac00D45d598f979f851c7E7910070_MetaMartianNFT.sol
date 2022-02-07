// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MRC721.sol";

contract MetaMartianNFT is MRC721{

	constructor(
    ) MRC721(
    	"Meta Martian NFT", 
    	"MMN",
        "https://mmac-meta-martian.communitynftproject.io/"
    ){
    	
    }
}