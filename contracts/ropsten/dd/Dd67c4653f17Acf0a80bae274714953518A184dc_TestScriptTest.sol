// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*

 ________   ______  ________ 
|        \ /      \|        \
 \$$$$$$$$|  $$$$$$\\$$$$$$$$
   | $$   | $$___\$$  | $$   
   | $$    \$$    \   | $$   
   | $$    _\$$$$$$\  | $$   
   | $$   |  \__| $$  | $$   
   | $$    \$$    $$  | $$   
    \$$     \$$$$$$    \$$   
                                                                                     
    TEST / 2021 / V2.0
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TestScriptTest is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 public constant TST_GIFT = 2;
    uint256 public constant TST_PUBLIC = 4;
    uint256 public constant TST_MAX = TST_GIFT + TST_PUBLIC;
    uint256 public constant TST_PRICE = 0.01 ether;
    uint256 public constant TST_PER_MINT = 5;

    mapping(string => bool) private _usedNonces;

    string private _contractURI;
    string private _tokenBaseURI = "https://tst.gg/api/";
    address private _devAddress = 0xd2161328A17E0F3D634fB6a3d158e54f489EE44A;
    address private _signerAddress = 0xd2161328A17E0F3D634fB6a3d158e54f489EE44A;

    string public proof;
    uint256 public giftedAmount;
    uint256 public publicAmountMinted;
    bool public saleLive;
    bool public locked;

    constructor() ERC721("TestScriptTest", "TST") { }

    modifier notLocked {
        require(!locked, "Locked");
        _;
    }

    function hashTransaction(address sender, uint256 qty, string memory nonce) private pure returns(bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, qty, nonce)))
        );

        return hash;
    }

    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return _signerAddress == hash.recover(signature);
    }

    function buy(string memory nonce, uint256 tokenQuantity) external payable {
        require(saleLive, "SALE_CLOSED");
        require(tokenQuantity <= TST_PER_MINT, "EXCEED_TST_PER_MINT");
        require(TST_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");

        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicAmountMinted++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        _usedNonces[nonce] = true;
    }

    function gift(address[] calldata receivers) external onlyOwner {
        require(totalSupply() + receivers.length <= TST_MAX, "MAX_MINT");
        require(giftedAmount + receivers.length <= TST_GIFT, "GIFTS_EMPTY");

        for (uint256 i = 0; i < receivers.length; i++) {
            giftedAmount++;
            _safeMint(receivers[i], totalSupply() + 1);
        }
    }

    function withdraw() external onlyOwner {
        payable(_devAddress).transfer(address(this).balance * 1 / 3);
        payable(msg.sender).transfer(address(this).balance);
    }

    // Owner functions for enabling presale, sale, revealing and setting the provenance hash
    function lockMetadata() external onlyOwner {
        locked = true;
    }


    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

    function setProvenanceHash(string calldata hash) external onlyOwner notLocked {
        proof = hash;
    }

    function setContractURI(string calldata URI) external onlyOwner notLocked {
        _contractURI = URI;
    }

    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        _tokenBaseURI = URI;
    }

    // aWYgeW91IHJlYWQgdGhpcywgc2VuZCBGcmVkZXJpayMwMDAxLCAiZnJlZGR5IGlzIGJpZyI=
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }
}