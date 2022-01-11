//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract FoTest is ERC721Enumerable, Ownable {

    string _baseTokenURI = 'https://bucleinfinito.com.ar/api/fot/';

    uint256 private _price = 0.01 ether;

    constructor() public ERC721("Fo Test 02", "FOT") {}

    uint256 public saleState = 0; // 0 = paused, 1 = presale, 2 = live

    address t1 = 0x6B8dD6bBfE072dE01D2417cA8dDd5a9B76502786;
    address t2 = 0x73d9e612c704D1CA0c81ebF0D161dd65d0C5F246;

    function setSaleState(uint256 _saleState) public onlyOwner {
        saleState = _saleState;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 _each = address(this).balance / 5;
        require(payable(t1).send(_each));
        require(payable(t2).send(_each));
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

    function setPrice(uint256 _newPrice) public onlyOwner {
        _price = _newPrice;
    }

    function mintCat(uint256 numberOfTokens) public payable {
        uint256 supply = totalSupply();

        if (msg.sender != owner()) {
            require(saleState > 1, 'Sale must be active to mint');
        }
        
        if (msg.sender != owner()) {
            require(
                msg.value >= _price * numberOfTokens,
                'Ether sent is not correct'
            );
        }

        for (uint256 i = 1; i <= numberOfTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
}