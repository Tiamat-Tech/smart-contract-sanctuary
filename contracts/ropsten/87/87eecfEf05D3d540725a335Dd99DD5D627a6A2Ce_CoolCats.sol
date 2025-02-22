// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoolCats is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string _baseTokenURI;
    uint256 private _reserved = 0;
    uint256 private _price = 0.01 ether;
    bool public _paused = true;

    // withdraw addresses
    address t1 = 0x717a73B3E2FaF66D1B119AF9fdDD75D27680c5b7;
    address t2 = 0xB0D0D10B6e436CD298224eE4340198f85d3C6a33;

    // Cool Cats are so cool they dont need a lots of complicated code :)
    // 9999 cats in total, cos cats have 9 lives
    // constructor(string memory baseURI) ERC721("Cool Cats", "COOL") {
    //     setBaseURI(baseURI);

    //     // team gets the first 2 cats
    //     _safeMint(t1, 0);
    //     _safeMint(t2, 1);
    // }

    constructor() ERC721("Cool Cats", "COOL") {}

    function adopt(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(!_paused, "Sale paused");
        require(num < 21, "You can adopt a maximum of 20 Cats");
        require(supply + num < 9 - _reserved, "Exceeds maximum Cats supply");
        require(msg.value >= _price * num, "Ether sent is not correct");

        for (uint256 i; i < num; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    // Just in case Eth does some crazy stuff
    function setPrice(uint256 _newPrice) public onlyOwner {
        _price = _newPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint256) {
        return _price;
    }

    function giveAway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= _reserved, "Exceeds reserved Cat supply");

        uint256 supply = totalSupply();
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply + i);
        }

        _reserved -= _amount;
    }

    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 _each = address(this).balance / 2;
        require(payable(t1).send(_each));
        require(payable(t2).send(_each));
    }
}