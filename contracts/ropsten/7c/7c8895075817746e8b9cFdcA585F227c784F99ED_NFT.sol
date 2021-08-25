//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MINT_LIMIT = 2;
    uint256 public constant MAX_PRIVATE_SUPPLY = 3;
    uint256 public constant MAX_PUBLIC_SUPPLY = 5;
    uint256 public constant MAX_SUPPLY = MAX_PRIVATE_SUPPLY + MAX_PUBLIC_SUPPLY;

    uint256 public cost = 0.004 ether;
    bool public isActive = false;
    uint256 public totalPrivateSupply;
    uint256 public totalPublicSupply;

    string private _baseURI = "";

    constructor(string memory baseURI) ERC721("NAH FUNGIBLE BONES", "NFB") {
        setBaseURI(baseURI);
    }

    function gift(address to, uint256 num) external onlyOwner {
        require(totalSupply() < MAX_SUPPLY + 1, "All tokens minted");
        require(
            totalPrivateSupply + num < MAX_PRIVATE_SUPPLY + 1,
            "Exceeds private supply"
        );

        for (uint256 i; i < num; i++) {
            totalPrivateSupply += 1;
            _safeMint(to, totalPrivateSupply);
        }
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();

        require(isActive, "Contract is inactive");
        require(num < MINT_LIMIT + 1, "Over max limit");
        require(supply < MAX_SUPPLY, "All tokens minted");
        require(totalPublicSupply < MAX_PUBLIC_SUPPLY, "Over max public limit");
        require(msg.value >= cost * num, "ETH sent is not correct");

        for (uint256 i; i < num; i++) {
            if (totalPublicSupply < MAX_PUBLIC_SUPPLY) {
                totalPublicSupply += 1;
                _safeMint(msg.sender, MAX_PRIVATE_SUPPLY + totalPublicSupply);
            }
        }
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseURI = baseURI;
    }

    function setActive(bool val) public onlyOwner {
        isActive = val;
    }

    function setPrice(uint256 newPrice) public onlyOwner {
        cost = newPrice;
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}