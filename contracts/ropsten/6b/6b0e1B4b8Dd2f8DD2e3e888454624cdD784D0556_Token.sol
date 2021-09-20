// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract Token is ERC721Enumerable, Ownable {
    uint256 public constant PRICE = 0.05 ether;
    uint256 public constant maxTokenPurchase = 20;
    uint256 public MAX_TOKENS;
    bool public saleIsActive = false;
    string public baseTokenURI;
    uint256 private _top;
    uint256 private _bottom = 1;
    address private _devAddress;
    address private _artistAddress;

    constructor(
        address devAddress,
        address artistAddress,
        uint256 maxTokens,
        string memory tokenUri
    ) ERC721("Token", "nftToken") {
        _devAddress = devAddress;
        _artistAddress = artistAddress;
        MAX_TOKENS = maxTokens;
        _top = maxTokens;
        baseTokenURI = tokenUri;
    }

    function mintToken(uint256 numberOfTokens) external payable {
        require(saleIsActive, "Sale must be active to mint");
        require(numberOfTokens <= maxTokenPurchase, "Can only mint 20 tokens at a time");
        require(totalSupply() + numberOfTokens <= MAX_TOKENS,"Purchase would exceed max supply");
        require(PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            if (totalSupply() < MAX_TOKENS) {
                uint256 coin = flipCoin();
                if (coin == 0) {
                    _safeMint(msg.sender, _bottom);
                    _bottom += 1;
                } else {
                    _safeMint(msg.sender, _top);
                    _top -= 1;
                }
            }
        }
    }

    function flipCoin() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp,block.difficulty,msg.sender,_top,_bottom))) % 2;
    }

    function withdrawAll() external payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Cannot withdraw 0");
        _widthdraw(_devAddress, balance / 2);
        _widthdraw(_artistAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
}