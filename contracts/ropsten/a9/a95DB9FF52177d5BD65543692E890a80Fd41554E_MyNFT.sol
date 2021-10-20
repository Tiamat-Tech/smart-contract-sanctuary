//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Testing other functions
    mapping(address => string) private _holderLevel;
    event _holderLevelChanged(address recipient, string newLevel);

    constructor() public ERC721("MyNFT", "NFT") {
        _setBaseURI("https://my-json-server.typicode.com/Tarekka/demo/posts/");
    }

    function baseTokenURI() public view returns (string memory) {
        return baseURI();
    }

    // Testing ether functions//
    function deposit() public payable {}

    // Function to withdraw all Ether from this contract.
    function withdraw() public {
        uint256 amount = address(this).balance;
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    //end Testing//
    // function mintAllNFTS() public onlyOwner {
    //     for(uint i = 0; i < 1000; i++){
    //         _mint(owner(), i);
    //     }
    // }
    
    function mintNFT(address recipient, string memory tokenURI)
        public
        onlyOwner
        payable
        returns (uint256)
    {
        require(msg.value == 0.08 ether, 'Price should be 0.08');
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function setLevel(address recipient, string memory newLevel)
        public
        returns (string memory)
    {
        require(balanceOf(recipient) > 0, "Not a holder");
        _holderLevel[recipient] = newLevel;
        emit _holderLevelChanged(recipient, newLevel);
        return "New level set!";
    }

    function getLevel(address recipient) public view returns (string memory) {
        return _holderLevel[recipient];
    }
}