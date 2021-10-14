// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Genosphere is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 public constant GENO_GIFT = 0;
    uint256 public constant GENO_PRIVATE = 1000;
    uint256 public constant GENO_PUBLIC = 9000;
    uint256 public constant GENO_MAX = GENO_GIFT + GENO_PRIVATE + GENO_PUBLIC;
    uint256 public constant GENO_PRICE = 0.08 ether;
    uint256 public constant GENO_PER_MINT = 5;
    
    mapping(address => bool) public presalerList;
    mapping(address => uint256) public presalerListPurchases;
    mapping(string => bool) private _usedNonces;
    
    string private _contractURI;
    string private _tokenBaseURI = "https://genosphere.com/api/metadata/";
    // address private _artistAddress = 0x25aCE5971522A80fdAcAFBE50dFBDf659B861B25;
    address private _signerAddress = 0x7e3999B106E4Ef472E569b772bF7F7647D8F26Ba;

    string public proof;
    uint256 public giftedAmount;
    uint256 public publicAmountMinted;
    uint256 public privateAmountMinted;
    uint256 public presalePurchaseLimit = 2;
    bool public presaleLive;
    bool public saleLive;
    // bool public locked;
    
    constructor() ERC721("Genosphere", "GKIN") { }
    
    // modifier notLocked {
    //     require(!locked, "Contract metadata methods are locked");
    //     _;
    // }
    
    function addToPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(!presalerList[entry], "DUPLICATE_ENTRY");

            presalerList[entry] = true;
        }   
    }

    function removeFromPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            
            presalerList[entry] = false;
        }
    }
    
    function hashTransaction(address sender, uint256 qty, string memory nonce) private pure returns(bytes32) {
          bytes32 hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(sender, qty, nonce)))
          );
          
          return hash;
    }
    
    function matchAddressSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return _signerAddress == hash.recover(signature);
    }
    
    function buy(bytes32 hash, bytes memory signature, string memory nonce, uint256 tokenQuantity) external payable {
        require(saleLive, "SALE_CLOSED");
        require(!presaleLive, "ONLY_PRESALE");
        require(matchAddressSigner(hash, signature), "DIRECT_MINT_DISALLOWED");
        require(!_usedNonces[nonce], "HASH_USED");
        require(hashTransaction(msg.sender, tokenQuantity, nonce) == hash, "HASH_FAIL");
        require(totalSupply() < GENO_MAX, "OUT_OF_STOCK");
        require(publicAmountMinted + tokenQuantity <= GENO_PUBLIC, "EXCEED_PUBLIC");
        require(tokenQuantity <= GENO_PER_MINT, "EXCEED_GENO_PER_MINT");
        require(GENO_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        
        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicAmountMinted++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        
        _usedNonces[nonce] = true;
    }
    
    function presaleBuy(uint256 tokenQuantity) external payable {
        require(!saleLive && presaleLive, "PRESALE_CLOSED");
        require(presalerList[msg.sender], "NOT_QUALIFIED");
        require(totalSupply() < GENO_MAX, "OUT_OF_STOCK");
        require(privateAmountMinted + tokenQuantity <= GENO_PRIVATE, "EXCEED_PRIVATE");
        require(presalerListPurchases[msg.sender] + tokenQuantity <= presalePurchaseLimit, "EXCEED_ALLOC");
        require(GENO_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        
        for (uint256 i = 0; i < tokenQuantity; i++) {
            privateAmountMinted++;
            presalerListPurchases[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }
    
    function gift(address[] calldata receivers) external onlyOwner {
        require(totalSupply() + receivers.length <= GENO_MAX, "MAX_MINT");
        require(giftedAmount + receivers.length <= GENO_GIFT, "GIFTS_EMPTY");
        
        for (uint256 i = 0; i < receivers.length; i++) {
            giftedAmount++;
            _safeMint(receivers[i], totalSupply() + 1);
        }
    }
    
    function withdraw() external onlyOwner {
        // payable(_artistAddress).transfer(address(this).balance * 2 / 5);
        payable(msg.sender).transfer(address(this).balance);
    }
    
    function isPresaler(address addr) external view returns (bool) {
        return presalerList[addr];
    }
    
    function presalePurchasedCount(address addr) external view returns (uint256) {
        return presalerListPurchases[addr];
    }
    
    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    // function lockMetadata() external onlyOwner {
    //     locked = true;
    // }
    
    function togglePresaleStatus() external onlyOwner {
        presaleLive = !presaleLive;
    }
    
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
    
    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }
    
    // function setProvenanceHash(string calldata hash) external onlyOwner notLocked {
    //     proof = hash;
    // }
    
    // function setContractURI(string calldata URI) external onlyOwner notLocked {
    //     _contractURI = URI;
    // }
    
    // function setBaseURI(string calldata URI) external onlyOwner notLocked {
    //     _tokenBaseURI = URI;
    // }
    
    function setProvenanceHash(string calldata hash) external onlyOwner {
        proof = hash;
    }
    
    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }
    
    function setBaseURI(string calldata URI) external onlyOwner {
        _tokenBaseURI = URI;
    }
    
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");
        
        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }
}