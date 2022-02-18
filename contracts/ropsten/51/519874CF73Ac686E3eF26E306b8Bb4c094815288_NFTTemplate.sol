// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './ERC721Enumerable.sol';
import './Ownable.sol';

contract NFTTemplate is ERC721Enumerable, Ownable {

    uint256 public MAX_MINT = 21;
    uint256 public price = 0.001 ether;
    uint256 public MAX_TOTAL = 10000;

    string public baseTokenURI;

    address public withdrawAddress;
    address public stevenAddress;

    constructor() ERC721("NFT_NAME", "NFT_SYMBOL")  {
        withdrawAddress = msg.sender;
        stevenAddress = 0x7940450e9186669BED08A1c29e44D197ba3619B9;
        setBaseURI("https://badgameshow.com/");
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(num < MAX_MINT, "You can adopt a maximum of 20 Cats");
        require(supply + num < MAX_TOTAL, "Exceeds maximum Cats supply");
        require(msg.value >= price * num, "Ether sent is not correct");

        for (uint256 i; i < num; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function walletOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokensId = new uint256[](tokenCount);

        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(withdrawAddress).send(address(this).balance * 8 / 10));
        require(payable(stevenAddress).send(address(this).balance * 2 / 10));
    }
}