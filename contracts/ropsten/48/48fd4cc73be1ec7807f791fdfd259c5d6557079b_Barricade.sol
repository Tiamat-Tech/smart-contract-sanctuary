//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Barricade is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    // base token information
    uint256 public constant price = 0.04 ether;
    uint256 public constant totalAvailable = 8888;

    // mint status information
    uint256 public constant maxPerTxn = 10;
    bool public saleIsActive = false;

    // other state information
    uint256 public nextTokenID;

    constructor() ERC721("Barricade", "BAR") {
        nextTokenID = 1;
    }

    function startSale() external onlyOwner {
        saleIsActive = true;
    }

    function stopSale() external onlyOwner {
        saleIsActive = false;
    }

    function buyBarricade(uint256 numberOfTokens) external payable {
        require(saleIsActive, "token is not available for mint at this time");
        require(numberOfTokens <= maxPerTxn, "too many tokens requested");
        require(
            totalSupply().add(numberOfTokens) <= totalAvailable,
            "supply exceed"
        );
        require(
            price.mul(numberOfTokens) <= msg.value,
            "Not Enough Ether Sent"
        );
        for (uint256 i = 0; i < numberOfTokens; i++) {
            if (nextTokenID <= totalAvailable) {
                _safeMint(msg.sender, nextTokenID);
                nextTokenID = nextTokenID + 1;
            }
        }
    }

    function withdrawalFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        address payable owner = payable(owner());
        owner.transfer(balance);
    }
}