// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract KDC is ERC721Enumerable, Ownable {
    // techno viking wallet address
    // address tv = '0xc5C7e3a4A15412A9db2119E0Fb21366d6631b971';
    address public constant tvTest = 0xcFfad73E49CefDD02F73DC0D6D5dA0b8898BcD9f;

    string _baseTokenUri;
    uint256 public _maxBeats = 909; // TR-909
    uint256 private _price = 0.001 ether; // TB-303
    uint256 private _reservedBeats = 20; // giveaway 20 beats
    bool public _paused = false;

    constructor(string memory _baseURI) ERC721("Kopenicker Dance Club", "KDC"){
        setBaseURI(_baseURI);
        _safeMint(tvTest, 0);
        _safeMint(tvTest, 1);
    }

    event BeatMint(uint256 indexed tokenId);

    function mintBeat(uint256 amount) public payable {
        uint256 totalBeats = totalSupply();
        require(!_paused, "KDC is paused");
        require(totalBeats + 1 <= _maxBeats - _reservedBeats, "No more beats available");
        require(msg.value >= amount * _price, "Not enough ETH");
        require(amount > 0 && amount <= 10, "Max 10 beats per tx");

        for(uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, totalBeats + i);
            emit BeatMint(totalBeats + i);
        }
    }

    function baseURI() public view returns (string memory) {
        return _baseTokenUri;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _baseTokenUri = _baseURI;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        require(payable(tvTest).send(amount));
    }

    function pause(bool _pause) public onlyOwner {
        _paused = _pause;
    }
}