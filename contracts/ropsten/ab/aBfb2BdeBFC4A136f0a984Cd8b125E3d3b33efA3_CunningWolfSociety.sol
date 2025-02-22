// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Cunning Wolf Society / 2022 / V8008.1
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CunningWolfSociety is ERC721, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenSupply;

    uint256 public constant CWS_TOTAL = 20;

    uint256 public constant CWS_PRICE_PRESALE = 0.068 ether;
    uint256 public CWS_PRICE_SALE = 0.088 ether;

    uint256 public constant CWS_PER_GIFT = 2;
    uint256 public constant CWS_PER_PRESALE = 3;
    uint256 public constant CWS_PER_SALE = 5;
    uint256 public constant CWS_COMMUNITY_TREASURY = 5;

    mapping(address => bool) public giftList;
    mapping(address => bool) gifterListPurchases;
    mapping(address => uint256) presalerListPurchases;

    string private _contractURI;
    string private _tokenBaseURI;
    address private _artistAddress = 0xeab31655C95266Bb6b1a481b510cdB803DeACa66;
    address private _signerAddress = 0xbff089ACEe42af06f6cA4E7e5A59c626bdF7A8c0;

    bool public presaleLive = false;
    bool public saleLive = false;
    bool public locked = false;

    bytes32 public merkleRoot;

    constructor() ERC721("Cunning Wolf Society", "CWS") {
        _tokenBaseURI = "ipfs://QmTmFQpfYgCzg6Wqb1gKtpRMrNVVfUht5cMFL5VDKoZFXh";
        merkleRoot = "";
    }

    modifier notLocked {
        require(!locked, "Contract metadata methods are locked");
        _;
    }

    function addToGiftList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(!giftList[entry], "DUPLICATE_ENTRY");

            giftList[entry] = true;
        }
    }

    function removeFromGiftList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");

            giftList[entry] = false;
        }
    }

    function giftCommunity() external onlyOwner {
        require(_tokenSupply.current() + CWS_COMMUNITY_TREASURY <= CWS_TOTAL, "MAX_MINT_ACHIEVED");

        for (uint256 i = 0; i < CWS_COMMUNITY_TREASURY; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function gift() external {
        require(presaleLive || saleLive, "SALES_CLOSED");
        require(giftList[msg.sender], "NOT_QUALIFIED_FOR_GIFTING");
        require(!gifterListPurchases[msg.sender], "ADDRESS_ALREADY_GIFTED");
        require(_tokenSupply.current() + CWS_PER_GIFT <= CWS_TOTAL, "EXCEED_MAX_MINT");

        gifterListPurchases[msg.sender] = true;

        for (uint256 i = 0; i < CWS_PER_GIFT; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function mintWhitelist(uint256 tokenQuantity, bytes32[] calldata proof) external payable {
        require(presaleLive && !saleLive, "PRESALE_CLOSED");
        require(_verify(_leaf(msg.sender), proof), "INVALID_PROOF");
        require(tokenQuantity > 0, "MINIMUM_ONE_TOKEN_PER_MINT");
        require(_tokenSupply.current() + tokenQuantity <= CWS_TOTAL, "EXCEED_MAX_MINT");
        require(presalerListPurchases[msg.sender] + tokenQuantity <= CWS_PER_PRESALE, "EXCEED_ALLOC_PRESALE");
        require(CWS_PRICE_PRESALE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

        for (uint256 i = 0; i < tokenQuantity; i++) {
            presalerListPurchases[msg.sender]++;
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function buy(uint256 tokenQuantity) external payable {
        require(saleLive && !presaleLive, "SALE_CLOSED");
        require(tokenQuantity > 0, "MINIMUM_ONE_TOKEN_PER_MINT");
        require(tokenQuantity <= CWS_PER_SALE, "EXCEED_CWS_PER_MINT");
        require(_tokenSupply.current() + tokenQuantity <= CWS_TOTAL, "EXCEED_MAX_MINT");
        require(CWS_PRICE_SALE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

        for(uint256 i = 0; i < tokenQuantity; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function presalePurchasedCount(address addr) external view returns (uint256) {
        return presalerListPurchases[addr];
    }

    function gifted(address addr) external view returns (bool) {
        return gifterListPurchases[addr];
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }

    function getTokenSupply() public view returns (uint256) {
        return _tokenSupply.current();
    }

    //functions allowed only for OWNER
    function withdraw() external onlyOwner {
        uint _balance = address(this).balance;
        payable(_artistAddress).transfer(_balance * 1 / 2);
        payable(_signerAddress).transfer(_balance * 1 / 2);
    }

    function reduceSalePrice() external onlyOwner {
        CWS_PRICE_SALE = 0.044 ether;
    }

    function lockMetadata() external onlyOwner {
        locked = true;
    }

    function togglePresaleStatus() external onlyOwner {
        presaleLive = !presaleLive;
    }

    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }

    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

    function setContractURI(string calldata URI) external onlyOwner notLocked {
        _contractURI = URI;
    }

    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        _tokenBaseURI = URI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _verify(bytes32 _leafNode, bytes32[] memory proof) internal view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, _leafNode);
    }


}