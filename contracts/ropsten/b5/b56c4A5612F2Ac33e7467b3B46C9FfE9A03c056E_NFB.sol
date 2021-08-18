//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFB is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant maxMintLimit = 20;
    uint256 public constant maxSupply = 10000;

    uint256 public mintCost = 0.04 ether;
    bool public paused = false;

    string private _baseTokenURI;
    uint256 private _reserved = 100;

    address t1 = 0xDFFf1223CC700529B9AF8cC8cF869177fC05085c;

    constructor(string memory baseURI) ERC721("NAH FUNGIBLE BONES", "NFB") {
        setBaseURI(baseURI);
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(!paused, "Sale paused");
        require(num < maxMintLimit + 1, "Over max limit");
        require(supply + num < maxSupply - _reserved, "Exceeds maximum supply");
        require(msg.value >= mintCost * num, "Ether sent is not correct");

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

    function setPrice(uint256 newPrice) public onlyOwner {
        mintCost = newPrice;
    }

    function _baseURI() internal view virtual returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function giveAway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= _reserved, "Exceeds reserved supply");

        uint256 supply = totalSupply();
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply + i);
        }

        _reserved -= _amount;
    }

    function pause(bool val) public onlyOwner {
        paused = val;
    }

    function withdrawAll() public payable onlyOwner {
        uint256 _amount = address(this).balance;
        require(payable(t1).send(_amount));
    }
}