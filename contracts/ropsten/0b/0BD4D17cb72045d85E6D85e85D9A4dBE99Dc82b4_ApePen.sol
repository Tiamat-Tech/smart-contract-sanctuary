// contracts/Apen.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "Counters.sol";
import "Ownable.sol";


/// @title An NFT for Ape writers
/// @author rafi-fyi
/// @dev This is v0.01 intended for Ropsten testnet
contract ApePen is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    /// maximum pen amount
    uint256 public MAX_PENS;
    /// base purchase price for an ape pen
    uint256 public constant penPrice = 10000000000000000; //0.01 ETH

    constructor(uint256 maxNftSupply)
    ERC721("ApePen", "PEN") {
        MAX_PENS = maxNftSupply;
    }

    /// withdraw function for owner implemented using call over transfer
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        (bool success, ) =  payable(msg.sender).call{value:balance}("");
        require(success, "Transfer failed.");
    }

    /// simple mint function
    function mintNFT(address recipient, string memory tokenURI)
        public payable
        returns (uint256)
    {
        require(_tokenIds.current() + 1 <= MAX_PENS, "Mint would exceed max supply of Ape Pens");
        require(penPrice <= msg.value, "Ether value sent is not correct");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        // _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

    /// returns total minted pens, uses OpenZeppelin's Counters
    function getTotalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }
}