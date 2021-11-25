///SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTContract is ERC721 {
    uint tokenId;
    address owner;

    constructor() ERC721("IMMUTABLE TEST","IMT"){
        owner = msg.sender;
    }

    function mintToken(address to) external {
        _safeMint(to,tokenId);
    }

    function changeOwner(address newAddress) external {
        owner = newAddress;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmSvGccaCz8D8pjELLJysfgHHqcrx6v8oRXeCMgsQKCroS/";
    }

    modifier onlyOwner(){
        require(msg.sender == owner,"only owner");
        _;
    }

}