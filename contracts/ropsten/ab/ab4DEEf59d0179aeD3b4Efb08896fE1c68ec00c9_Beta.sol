// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "erc721a/contracts/ERC721A.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract Beta is ERC721A, Ownable {
    using Address for address;
    using SafeMath for uint256;

    // Opensea proxy Address
    address public proxyRegistryAddress =
        0xa5409ec958C83C3f309868babACA7c86DCB077c1;
    // Team Addresses
    address public address1 = 0xFB904f2B941a2Eef446ef27ADaC9Aa61458A163c; // User1
    address public address2 = 0x74d1a1A77725F126cb1FC0B213Bd8D32D804A413; // User2
    address public address3 = 0xFB904f2B941a2Eef446ef27ADaC9Aa61458A163c; // User3
    address public address4 = 0x74d1a1A77725F126cb1FC0B213Bd8D32D804A413; // User3

    // Sale Controls
    uint256 public presaleActive = 0;
    uint256 public reducedPresaleActive = 0;
    enum presaleTypes {
        FREE,
        PAID
    }
    mapping(address => uint256) public presaleClaims;

    //uint256 public constant teamSupply = 100;
    uint256 public constant maxSupply = 20;
    uint256 public constant presalelistMintPrice = 0.03 ether;
    uint256 public constant publicMintPrice = 0.05 ether;
    uint256 public maxPerTx = 5;
    uint256 public publicActive = 0;
    string public baseUri = "ipfs://xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

    constructor() ERC721A("Beta", "Beta") {}

    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    function setBaseURI(string memory _URI) external onlyOwner {
        baseUri = _URI;
    }

    // ================ Sale Controls ================ //

    // Pre Sale On/Off
    function setPresaleActive(uint256 value) public onlyOwner {
        presaleActive = value;
    }

    // Public Sale On/Off
    function setPublicSaleActive(uint256 value) public onlyOwner {
        publicActive = value;
    }

    // ================ Withdraw Functions ================ //

    // Withdrawl and distribute to team
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(address1, balance.mul(25).div(100)); // One
        _widthdraw(address2, balance.mul(25).div(100)); // Two
        _widthdraw(address3, balance.mul(25).div(100)); // Three
        _widthdraw(address4, address(this).balance); // Four
    }

    // Private Function -- Only Accesible By Contract
    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    // Emergency Withdraw Function -- Sends to owner wallet
    function emergencyWithdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(address1).transfer(balance);
    }

    // Minting Functions

    function publicMint(uint256 amount) external payable {
        require(publicActive > 0, "Public sale not live");
        require(amount < maxPerTx + 1, "Max per tx exceeded");
        require(msg.sender == tx.origin, "Bots not allowed");
        require(totalSupply() + amount < maxSupply + 1, "Collection sold out");
        require(
            publicMintPrice * amount == msg.value,
            "Incorrect eth amount sent"
        );
        _safeMint(msg.sender, amount);
    }

    //Need to redo signature verification for presale.  Pass any number for now
    function allowlistMint(uint256 amount, uint256 maxAmount) external payable {
        require(presaleActive > 0, "Presale is not live");
        require(totalSupply() + amount < maxSupply + 1, "Collecion Sold Out");
        //require(_verify(_signature), "bad signature");
        require(
            presaleClaims[msg.sender] + amount < maxAmount + 1,
            "Presale max claimed for address"
        );
        require(
            presalelistMintPrice * amount == msg.value,
            "Incorrect eth amount sent"
        );
        presaleClaims[msg.sender] += amount;
        _safeMint(msg.sender, amount);
    }
}