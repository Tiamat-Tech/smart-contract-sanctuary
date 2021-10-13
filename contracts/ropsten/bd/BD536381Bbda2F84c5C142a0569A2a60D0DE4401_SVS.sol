//SPDX-License-Identifier: UNLICENSED
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

pragma solidity ^0.8.4;
contract SVS is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 public constant SVS_GIFT = 0;
    uint256 public constant SVS_PRIVATE = 833;
    uint256 public constant SVS_PUBLIC = 7500;
    uint256 public constant SVS_MAX = SVS_GIFT + SVS_PRIVATE + SVS_PUBLIC;
    uint256 public constant SVS_PRICE = 0.08 ether;
    uint256 public constant SVS_PER_MINT = 5;
    
    mapping(address => bool) public presalerList;
    mapping(address => uint256) public presalerListPurchases;
    mapping(string => bool) private _usedNonces;
    
    string private _contractURI;
    string private _tokenBaseURI = "https://svs.gg/api/metadata/";
    address private _devAddress = 0xEd5aCD0db70aC997beB069679aAEEbD0fDb2E764;
                                     
    string public proof;
    uint256 public giftedAmount;
    uint256 public publicAmountMinted;
    uint256 public privateAmountMinted;
    uint256 public presalePurchaseLimit = 2;
    bool public presaleLive;
    bool public saleLive;
    bool public locked;
    
    constructor() ERC721("Sneaky Vampire Syndicate", "SVS") { }
    
    modifier notLocked {
        require(!locked, "Contract metadata methods are locked");
        _;
    }
    
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
    
    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return _devAddress == hash.recover(signature);
    }
    function buy(bytes32 hash, bytes memory signature, string memory nonce, uint256 tokenQuantity) external payable {
        require(saleLive, "SALE_CLOSED");
        require(!presaleLive, "ONLY_PRESALE");
        require(matchAddresSigner(hash, signature), "DIRECT_MINT_DISALLOWED");
        require(!_usedNonces[nonce], "HASH_USED");
        require(hashTransaction(msg.sender, tokenQuantity, nonce) == hash, "HASH_FAIL");
        require(totalSupply() < SVS_MAX, "OUT_OF_STOCK");
        require(publicAmountMinted + tokenQuantity <= SVS_PUBLIC, "EXCEED_PUBLIC");
        require(tokenQuantity <= SVS_PER_MINT, "EXCEED_SVS_PER_MINT");
        require(SVS_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        
        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicAmountMinted++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        _usedNonces[nonce] = true;
    }
    function gift(address[] calldata receivers) external onlyOwner {
        require(totalSupply() + receivers.length <= SVS_MAX, "MAX_MINT");
        require(giftedAmount + receivers.length <= SVS_GIFT, "GIFTS_EMPTY");
        for (uint256 i = 0; i < receivers.length; i++) {
            giftedAmount++;
            _safeMint(receivers[i], totalSupply() + 1);
        }
    }
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadata() external onlyOwner {
        locked = true;
    }
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }
    function setSignerAddress(address addr) external onlyOwner {
        _devAddress = addr;
    }
    function setProvenanceHash(string calldata hash) external onlyOwner notLocked {
        proof = hash;
    }
    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        _tokenBaseURI = URI;
    }
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");
        
        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }
}