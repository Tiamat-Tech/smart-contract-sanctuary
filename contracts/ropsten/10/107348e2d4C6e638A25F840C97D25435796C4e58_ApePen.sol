// contracts/Apen.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "Counters.sol";

contract ApePen is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 public MAX_PENS;

    constructor(uint256 maxNftSupply) public ERC721("ApePen", "PEN") {
        MAX_PENS = maxNftSupply;
    }

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        require(_tokenIds.current() + 1 <= MAX_PENS, "Mint would exceed max supply of Ape Pens");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        // _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

    function getTotalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }
}