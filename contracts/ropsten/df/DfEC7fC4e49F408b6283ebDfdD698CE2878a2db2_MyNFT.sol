//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() public ERC721("MyNFT", "NFT") {}
    bool public paused;
    address public recipient;
    bool testVariable;

    function mintNFT()
        public payable
        returns (uint256)
    {
        require(paused == false, "Contract is Paused");
        require(msg.value >= 1, "Not enough ETH check price"); // 1 wei
        _tokenIds.increment();
        
        recipient = msg.sender;
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        return newItemId;
    }

    function setPaused(bool _paused) public {
        //require(msg.sender == owner, "You are not the owner");
        paused=_paused;
    }

    function setVariable() public {
        testVariable = !testVariable;
    }
}