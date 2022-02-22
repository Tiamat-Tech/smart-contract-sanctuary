// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './ERC721Enumerable.sol';
import './Ownable.sol';

contract MyNFT is ERC721Enumerable, Ownable {

    string baseTokenURI;
    uint256 MAX_MINT = 1;
    uint256 PROFIT = 10;
    uint256 public MAX_TOTAL = 2000;
    uint256 public price = 0.3 ether;

    address withdrawAddress;
    address stevenAddress = 0xAc4Ff7E04ce061826AAD93f826509D3d9E96682D;

    constructor() ERC721("MyNFT", "SXY")  {
        withdrawAddress = msg.sender;
        setBaseURI("https://badgameshow/");
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(num <= MAX_MINT, "You can adopt a maximum of MAX_MINT Cats");
        require(supply + num <= MAX_TOTAL, "Exceeds maximum Cats supply");
        require(msg.value >= price * num, "Ether sent is not correct");

        for (uint256 i; i < num; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function setWithdrawAddress(address _newAddress) public onlyOwner {
        withdrawAddress = _newAddress;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function withdrawAll() public onlyOwner {
        uint one = address(this).balance * (100 - PROFIT) / 100;
        uint two = address(this).balance * PROFIT / 100;
        require(payable(withdrawAddress).send(one));
        require(payable(stevenAddress).send(two));
    }

    function walletOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokensId = new uint256[](tokenCount);

        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokensId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}