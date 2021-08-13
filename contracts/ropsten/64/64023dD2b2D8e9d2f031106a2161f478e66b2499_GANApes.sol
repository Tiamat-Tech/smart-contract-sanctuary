// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract GANApes is ERC721Enumerable, Ownable {
    uint256 private constant MAX_APES = 6666;
    uint256 private constant INITIAL_SUPPLY = 32;
    uint256 private _availableApes;
    string private _baseUriString;

    constructor() ERC721('GAN Apes', 'GANApes') {
        _baseUriString = 'https://localhost.local/';
        _availableApes = 500 - INITIAL_SUPPLY;

        for (uint256 i; i < INITIAL_SUPPLY; i ++) {
            _safeMint(address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266), i);
        }
    }

    // solhint-disable-next-line code-complexity
    function getSalePrice(uint256 id) public view returns (uint256) {
        require(totalSupply() < MAX_APES, 'Sale ended');
        require(id >= 0 && id < MAX_APES, 'Id must be 0 <= x < 6666');

        if (id < 500) {
            return 4 * 1e7 gwei;
        } else if (id < 1000) {
            return 5 * 1e7 gwei;
        } else if (id < 2000) {
            return 6 * 1e7 gwei;
        } else if (id < 3000) {
            return 7 * 1e7 gwei;
        } else if (id < 4000) {
            return 8 * 1e7 gwei;
        } else if (id < 5000) {
            return 9 * 1e7 gwei;
        } else if (id < 6000) {
            return 10 * 1e7 gwei;
        } else {
            return 20 * 1e7 gwei;
        }
    }

    function adopt(uint256 quantity) public payable {
        require(totalSupply() < MAX_APES, 'No more adoptable apes');
        require(quantity > 0 && quantity <= 20, 'Quantity must be 0 < x <= 20');
        require(_availableApes >= quantity, 'Not enough available apes');
        require((totalSupply() + quantity) <= MAX_APES, 'Not enough adoptable apes');

        uint totalCost = 0;
        for (uint i = 0; i < quantity; i++) {
            totalCost += getSalePrice(totalSupply() + i);
        }
        require(msg.value >= totalCost, 'Ether value sent is below the price');

        for (uint i = 0; i < quantity; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
            _availableApes -= 1;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUriString;
    }

    // Admin functions
    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseUriString = baseURI_;
    }

    function addAvailable(uint256 availableApes_) public onlyOwner {
        _availableApes += availableApes_;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}