//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ClumsySquirrelV1 is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // PRICE OF NFT MINTING (wei)
    uint256 private NFTPrice = 50000000000000000;
    // PaymentSplitter contract address
    address private paymentSplitterAddress =
        0xC3BF93b8d4109532A8D7302f264f9654F80c0282;

    constructor() public ERC721("ClumsySquirrelV1", "CSQRL") {
        // No minting of NFT upon contrat deployment
    }

    // Anyone can mint an NFT
    function mintNFT(address recipient, string memory tokenURI) public payable {
        require(
            msg.value >= NFTPrice,
            "Please enter the correct NFT price for minting"
        );

        // Send funds to PaymentSplitter
        payable(address(paymentSplitterAddress)).transfer(msg.value);

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
    }
}