// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PunkX is ERC721, Ownable {

    using Address for address;
    using MerkleProof for bytes32[];

    string public baseTokenURI;

    uint public mintPrice = 0.25 ether;
    uint public collectionSize = 8888;
    uint public maxItemsPerTx = 2;
    uint public giveawayCount = 0;
    uint public giveawayMaxItems = 100;
    uint public totalSupply = 0;

    bool public whitelistMintPaused = true;
    bool public publicMintPaused = true;

    bytes32 whitelistMerkleRoot;

    mapping(address => uint) public whitelistMintedAmount;

    event Mint(address indexed owner, uint256 tokenId);

    constructor() ERC721("PunkX", "PUNKX") {}

    function setGiveawayamount(uint amount) public onlyOwner {
        giveawayMaxItems = amount;
    }

    function giveawayMint(address to, uint amount) external onlyOwner {
        require(giveawayCount + amount <= giveawayMaxItems, "giveawayMint: Surpasses cap");
        _mintWithoutValidation(to, amount);
        giveawayCount += amount;
    }

    function setWhitelistMintPaused(bool _whitelistMintPaused) public onlyOwner {
        whitelistMintPaused = _whitelistMintPaused;
    }

    function setWhitelistMintInfo(bytes32 _preSaleWhitelistMerkleRoot) public onlyOwner {
        whitelistMerkleRoot = _preSaleWhitelistMerkleRoot;
    }

    function isAddressWhitelistedForPreSale(bytes32[] memory proof, address _address) public view returns (bool) {
        return isAddressInMerkleRoot(whitelistMerkleRoot, proof, _address);
    }

    function whitelistMint(bytes32[] memory proof) external payable {
        require(!whitelistMintPaused, "whitelist mint paused");
        require(isAddressWhitelistedForPreSale(proof, msg.sender), "not eligible");

        uint remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        uint amount = msg.value / mintPrice;
        require(amount > 0, "amount to mint is 0");
        require(whitelistMintedAmount[msg.sender] + amount <= maxItemsPerTx, "exceed allowance per wallet");

        whitelistMintedAmount[msg.sender] += amount;

        _mintWithoutValidation(msg.sender, amount);
    }

    function setPublicMintPaused(bool _publicMintPaused) public onlyOwner {
        publicMintPaused = _publicMintPaused;
    }

    function publicMint() external payable {
        require(!publicMintPaused, "public mint paused");

        uint remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        uint amount = msg.value / mintPrice;

        require(amount > 0, "amount to mint is 0");
        require(amount <= maxItemsPerTx, "exceed allowance per tx");

        _mintWithoutValidation(msg.sender, amount);
    }

    function _mintWithoutValidation(address to, uint amount) internal {
        require((totalSupply + amount) <= collectionSize, "sold out");
        for (uint i = 0; i < amount; i++) {
            totalSupply += 1;
            _mint(to, totalSupply);
            emit Mint(to, totalSupply);
        }
    }

    function isAddressInMerkleRoot(bytes32 merkleRoot, bytes32[] memory proof, address _address) internal pure returns (bool) {
        return proof.verify(merkleRoot, keccak256(abi.encodePacked(_address)));
    }

    function setMintInfo(uint _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMaxItemsPerTrx(uint _maxItemsPerTrx) public onlyOwner {
        maxItemsPerTx = _maxItemsPerTrx;
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function withdrawAll(address to) external onlyOwner {
        sendEth(to, address(this).balance);
    }

    function sendEth(address to, uint amount) internal {
        (bool success,) = to.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}