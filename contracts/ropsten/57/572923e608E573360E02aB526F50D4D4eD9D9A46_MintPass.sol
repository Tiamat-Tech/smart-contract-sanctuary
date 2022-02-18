// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintPass is ERC1155Supply, Ownable {

    uint constant public MAXIMUM_SUPPLY = 250;
    uint constant public MINT_PASS = 0;
    uint public maxMintingPerTx = 2;
    uint public currentMintingFee = 8 ether / 100;

    constructor(string memory _baseUri) ERC1155(_baseUri) {}

    function mint(uint256 amount) public payable
    {
        require(msg.value >= amount * currentMintingFee, "Insufficent Minting Fee");
        require(totalSupply(MINT_PASS) + amount <= MAXIMUM_SUPPLY, "Total Supply = 250");
        require(amount <= maxMintingPerTx, "Limit 2 Per Wallet");
        _mint(msg.sender, MINT_PASS, amount, "");
    }

    function withdrawETH() external onlyOwner {
        owner().call{ value: address(this).balance }("");
    }

    function setMintingFee(uint256 weiAmount) external onlyOwner {
        currentMintingFee = weiAmount;
    }

    function setMaxMintingPerTx(uint256 _maxMintingPerTx) external onlyOwner {
        maxMintingPerTx = _maxMintingPerTx;
    }
}