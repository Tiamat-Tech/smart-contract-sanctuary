// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract PunkX is ERC721A, Ownable {
    using Address for address;
    using MerkleProof for bytes32[];

    string public baseTokenURI;

    uint256 public mintPrice = 0.25 ether;
    uint256 public collectionSize = 8888;
    uint256 public maxItemsPerTx = 2;
    uint256 public giveawayCount = 0;
    uint256 public giveawayMaxItems = 100;

    bool public whitelistMintPaused = true;
    bool public publicMintPaused = true;

    bytes32 whitelistMerkleRoot;

    mapping(address => uint256) public whitelistMintedAmount;

    event Mint(address indexed owner, uint256 tokenId);

    constructor() ERC721A("PunkX", "PUNKX", 50) {}

    function setGiveawayamount(uint256 amount) public onlyOwner {
        giveawayMaxItems = amount;
    }

    function giveawayMint(address to, uint256 amount) external onlyOwner {
        require(
            giveawayCount + amount <= giveawayMaxItems,
            "giveawayMint: Surpasses cap"
        );
        _mintWithoutValidation(to, amount);
        giveawayCount += amount;
    }

    function setWhitelistMintPaused(bool _whitelistMintPaused)
        public
        onlyOwner
    {
        whitelistMintPaused = _whitelistMintPaused;
    }

    function setWhitelistMintInfo(bytes32 _preSaleWhitelistMerkleRoot)
        public
        onlyOwner
    {
        whitelistMerkleRoot = _preSaleWhitelistMerkleRoot;
    }

    function isAddressWhitelistedForPreSale(
        bytes32[] memory proof,
        address _address
    ) public view returns (bool) {
        return isAddressInMerkleRoot(whitelistMerkleRoot, proof, _address);
    }

    function whitelistMint(bytes32[] memory proof) external payable {
        require(!whitelistMintPaused, "whitelist mint paused");
        require(
            isAddressWhitelistedForPreSale(proof, msg.sender),
            "not eligible"
        );

        uint256 remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        uint256 amount = msg.value / mintPrice;
        require(amount > 0, "amount to mint is 0");
        require(
            whitelistMintedAmount[msg.sender] + amount <= maxItemsPerTx,
            "exceed allowance per wallet"
        );

        whitelistMintedAmount[msg.sender] += amount;

        _mintWithoutValidation(msg.sender, amount);
    }

    function setPublicMintPaused(bool _publicMintPaused) public onlyOwner {
        publicMintPaused = _publicMintPaused;
    }

    function publicMint() external payable {
        require(!publicMintPaused, "public mint paused");

        uint256 remainder = msg.value % mintPrice;
        require(remainder == 0, "send a divisible amount of eth");

        uint256 amount = msg.value / mintPrice;

        require(amount > 0, "amount to mint is 0");
        require(amount <= maxItemsPerTx, "exceed allowance per tx");

        _mintWithoutValidation(msg.sender, amount);
    }

    function _mintWithoutValidation(address to, uint256 amount) internal {
        require((totalSupply() + amount) <= collectionSize, "sold out");
        _safeMint(to, amount);
        emit Mint(to, amount);
    }

    function isAddressInMerkleRoot(
        bytes32 merkleRoot,
        bytes32[] memory proof,
        address _address
    ) internal pure returns (bool) {
        return proof.verify(merkleRoot, keccak256(abi.encodePacked(_address)));
    }

    function setMintInfo(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMaxItemsPerTrx(uint256 _maxItemsPerTrx) public onlyOwner {
        maxItemsPerTx = _maxItemsPerTrx;
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function withdrawAll(address to) external onlyOwner {
        sendEth(to, address(this).balance);
    }

    function sendEth(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}