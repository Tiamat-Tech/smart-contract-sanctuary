// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
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

    bool public preMintPaused = true;
    bool public publicMintPaused = true;

    bytes32 preSaleWhitelistMerkleRoot;

    mapping(address => uint) public preSaleMintedAmount;

    event Mint(address indexed owner, uint256 tokenId);

    constructor() ERC721("PunkX", "PUNKX") {}

    /*
    GIVEAWAY FUNCTIONS - START
    */
    function setGiveawayamount(uint amount) public onlyOwner {
        giveawayMaxItems = amount;
    }

    function giveawayMint(address to, uint amount) external onlyOwner {
        require(giveawayCount + amount <= giveawayMaxItems, "giveawayMint: Surpasses cap");
        _mintWithoutValidation(to, amount);
        giveawayCount += amount;
    }
    /*
    GIVEAWAY FUNCTIONS - END
    */

    /*
    PRE MINT - START
    */
    function setPreMintPaused(bool _preMintPaused) public onlyOwner {
        preMintPaused = _preMintPaused;
    }

    function setPreSaleEventMintInfo(bytes32 _preSaleWhitelistMerkleRoot) public onlyOwner {
        preSaleWhitelistMerkleRoot = _preSaleWhitelistMerkleRoot;
    }

    function isAddressWhitelistedForPreSale(bytes32[] memory proof, address _address) public view returns (bool) {
        return isAddressInMerkleRoot(preSaleWhitelistMerkleRoot, proof, _address);
    }

    function preMint(bytes32[] memory proof) external payable {
        require(!preMintPaused, "mint paused");
        require(isAddressWhitelistedForPreSale(proof, msg.sender), "not eligible");
        // verify that the client sent enough eth to pay for the mint
        uint remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        // calculate the amount of tokens we are minting based on the amount of eth sent
        uint amount = msg.value / mintPrice;
        require(amount > 0, "amount to mint is 0");
        require(preSaleMintedAmount[msg.sender] + amount <= maxItemsPerTx, "exceed allowance per wallet");

        preSaleMintedAmount[msg.sender] += amount;

        _mintWithoutValidation(msg.sender, amount);
    }
    /*
    PRE MINT - END
    */

    /*
    PUBLIC MINT FUNCTIONS - START
    */
    function setPublicMintPaused(bool _publicMintPaused) public onlyOwner {
        publicMintPaused = _publicMintPaused;
    }

    function publicMint() external payable {
        // publicMintPaused is set by owner calling pausePublicMint and unpausePublicMint
        require(!publicMintPaused, "mint paused");
        // verify that the client sent enough eth to pay for the mint
        uint remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        // calculate the amount of tokens we are minting based on the amount of eth sent
        uint amount = msg.value / mintPrice;

        require(amount > 0, "amount to mint is 0");
        require(amount <= maxItemsPerTx, "max 2 per tx");

        _mintWithoutValidation(msg.sender, amount);
    }
    /*
    PUBLIC MINT FUNCTIONS - END
    */

    /*
    HELPER FUNCTIONS - START
    */
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
    /*
    HELPER FUNCTIONS - END
    */

    /*
    ADMIN FUNCTIONS - BEGIN
    */
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
    /*
    ADMIN FUNCTIONS - END
    */

    /*
    REQUIRED BY SOLIDITY - START
    */
    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
    /*
    REQUIRED BY SOLIDITY - END
    */
}