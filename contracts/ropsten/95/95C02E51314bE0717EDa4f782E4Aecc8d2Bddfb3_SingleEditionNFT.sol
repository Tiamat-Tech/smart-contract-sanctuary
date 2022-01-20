// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract SingleEditionNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    address contractAddress;

    constructor(address _marketplaceAddress) ERC721("MintIt", "MIT") {
        contractAddress = _marketplaceAddress;
    }

    function createToken(string memory _tokenURI) public returns (uint256) {
        tokenIds.increment();
        uint256 newItemId = tokenIds.current();

        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        setApprovalForAll(contractAddress, true);
        return newItemId;
    }

    /**
     * @dev calculates the next token ID based on value of tokenIds
     * @return uint256 for the next token ID
     */
    function _getCurrentTokenID() public view returns (uint256) {
        return tokenIds.current();
    }
}