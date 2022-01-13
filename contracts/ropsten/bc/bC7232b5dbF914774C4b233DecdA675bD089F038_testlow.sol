// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title testlow
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract testlow is ERC721, Ownable {

    string private _baseURIextended;
    uint256 public publicTokenPrice = 0.001 ether;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    constructor() ERC721("testlow", "TESTLOW") {
    }

    function totalSupply() public view returns (uint256 supply) {
        return _tokenSupply.current();
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function updatePublicPrice(uint256 newPrice) public onlyOwner {
        publicTokenPrice = newPrice;
    }

    function mint(uint _mintAmount) external payable {
        require(_mintAmount < 20, "Exceeded max token purchase");
        require(_tokenSupply.current() + _mintAmount < 100, "Purchase would exceed max supply of tokens");

        for(uint i = 0; i < _mintAmount; i++) {
            _safeMint(msg.sender, _tokenSupply.current());
            _tokenSupply.increment();
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

}