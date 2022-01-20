// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract MultipleEditionNFT is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    address contractAddress;
    mapping(uint256 => string) private uris;

    constructor(address _marketplaceAddress)
        ERC1155("https://ipfs.infura.io/ipfs/{id}.json")
    {
        contractAddress = _marketplaceAddress;
    }

    function createToken(uint256 _quantity, string memory _uri)
        public
        returns (uint256)
    {
        tokenIds.increment();
        uint256 newTokenTypeId = tokenIds.current();

        _mint(msg.sender, newTokenTypeId, _quantity, "");
        uris[newTokenTypeId] = _uri;
        setApprovalForAll(contractAddress, true);
        return newTokenTypeId;
    }

    function uri(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return (uris[_tokenId]);
    }

    /**
     * @dev calculates the next token ID based on value of tokenIds
     * @return uint256 for the next token ID
     */
    function _getCurrentTokenID() public view returns (uint256) {
        return tokenIds.current();
    }
}