// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/Counters.sol";


contract NFT1 is ERC721, Ownable {

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string _baseTokenURI;
    uint256 private _price = 0.06 ether;

    constructor() ERC721("NFT1", "NFT1")  {
    }

    function mint(uint256 num) public payable {
        require( msg.value >= _price * num, "Ether sent is not correct" );
        for(uint256 i; i < num; i++){
            _tokenIds.increment();
            // _safeMint( msg.sender, _tokenIds.current());
            _mint(msg.sender, _tokenIds.current());
        }
    }

    function giveaway(uint256 num) public onlyOwner {
        for(uint256 i; i < num; i++){
            _tokenIds.increment();
            // _safeMint( msg.sender, _tokenIds.current());
            _mint(msg.sender, _tokenIds.current());
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }
}