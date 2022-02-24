//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";

contract ApesTogether is ERC721A, Ownable {
    uint256 public constant mintPrice = 0.65 ether;
    uint256 public constant maxSupply = 1000;

    address public bankAddress;
    string public baseURI = "ipfs://TODO";
    string public contractURI = "ipfs://TODO";
    bool public saleActive = false;

    constructor(address _bankAddress) ERC721A("ApesTogether", "APES") {
        bankAddress = _bankAddress;
    }

    modifier callerIsUser() {
        require(tx.origin == _msgSender(), "Caller is contract");
        _;
    }

    function setBankAddress(address _bankAddress) external onlyOwner {
        bankAddress = _bankAddress;
    }

    function setSale(bool _state) external onlyOwner {
        saleActive = _state;
    }

    function mint(uint256 quantity) external payable callerIsUser {
        uint256 totalSupply = totalSupply();
        require(saleActive, "Sale is not active");
        require(totalSupply + quantity < maxSupply, "Exceeds max supply");
        require(quantity * mintPrice == msg.value, "Invalid funds provided");
        _safeMint(msg.sender, quantity);
    }

    function withdraw() public onlyOwner{
        (bool success, ) = bankAddress.call{value: address(this).balance}("");
        require(success, "Failed to pay the bills");
    }
}