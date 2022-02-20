// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./base/ERC721Tradable.sol";

contract BHMasterToken is ERC721Tradable {
    using SafeMath for uint256;

    string private baseTokenUri = "";
    uint8 public maxSupply = 3;
    uint64 public tokenPrice = (5e18 / 100); //0.05 eth
    bool public saleActive = false;
    mapping(address => bool) internal whiteList;

    constructor() ERC721Tradable("BHM Token", "BHMT") {}

    function setBaseTokenURI(string memory newBaseTokenUri) external onlyOwner {
        baseTokenUri = newBaseTokenUri;
    }

    function setSaleActive(bool isActive) public onlyOwner {
        saleActive = isActive;
    }

    function setWhiteList(address[] calldata addresses, bool canMint) external onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteList[addresses[i]] = canMint;
        }
    }

    // also require a check somewhere that msg.value > 0 ?
    // https://ethereum.stackexchange.com/questions/70255/reason-for-check-of-msg-value-0

    function mintToken() external payable {
        require(saleActive, "Sale must be active to mint.");
        require(whiteList[_msgSender()] == true, "Caller not whitelisted");
        require(totalSupply() < maxSupply, "Token is sold out!");
        require(msg.value >= tokenPrice, "Ethereum sent is not sufficient.");
        require(msg.value > 0, "Ethereum sent is 0.");
        mintTo(msg.sender);
    }

    function withdrawBalance() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function baseTokenURI() public view override returns (string memory) {
        return baseTokenUri;
    }

    function contractURI() public pure returns (string memory) {
        return "http://localhost/api/contract/gimbles/";
    }
}