// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/*
 █     █░ ▒█████   ██▀███    ██████  ██░ ██  ██▓ ██▓███
▓█░ █ ░█░▒██▒  ██▒▓██ ▒ ██▒▒██    ▒ ▓██░ ██▒▓██▒▓██░  ██▒
▒█░ █ ░█ ▒██░  ██▒▓██ ░▄█ ▒░ ▓██▄   ▒██▀▀██░▒██▒▓██░ ██▓▒
░█░ █ ░█ ▒██   ██░▒██▀▀█▄    ▒   ██▒░▓█ ░██ ░██░▒██▄█▓▒ ▒
░░██▒██▓ ░ ████▓▒░░██▓ ▒██▒▒██████▒▒░▓█▒░██▓░██░▒██▒ ░  ░
░ ▓░▒ ▒  ░ ▒░▒░▒░ ░ ▒▓ ░▒▓░▒ ▒▓▒ ▒ ░ ▒ ░░▒░▒░▓  ▒▓▒░ ░  ░
  ▒ ░ ░    ░ ▒ ▒░   ░▒ ░ ▒░░ ░▒  ░ ░ ▒ ░▒░ ░ ▒ ░░▒ ░
  ░   ░  ░ ░ ░ ▒    ░░   ░ ░  ░  ░   ░  ░░ ░ ▒ ░░░
    ░        ░ ░     ░           ░   ░  ░  ░ ░
*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ChosenOnes is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint16 public constant TX_LIMIT = 7;
    uint16 public constant GIFT_SUPPLY = 444;
    uint16 public constant MAX_SUPPLY = 11111;
    uint16 public constant PRESALE_LIMIT = 3;
    uint256 public constant PRICE = 0.1 ether;

    string public contractURI;
    string public baseURI;
    string public provenance;
    uint16 public giftedAmount;
    bool public saleActive = false;
    bool public presaleActive = false;
    bool public locked;

    address private _signerAddress;

    mapping(address => uint256) public presaleTokensClaimed;
    mapping(address => mapping(uint256 => bool)) private _usedNonces;

    constructor() ERC721("ChosenOnes", "ONES") {}

    modifier notLocked() {
        require(!locked, "LOCKED");
        _;
    }

    // INTERNAL
    function hashTransaction(
        address sender,
        uint256 qty,
        uint256 nonce
    ) private pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(sender, qty, nonce))
                .toEthSignedMessageHash();
    }

    function matchSigner(bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        return _signerAddress == hash.recover(signature);
    }

    // ONLY OWNER
    function toggleSale(bool isPresale) external onlyOwner {
        if (isPresale) presaleActive = !presaleActive;
        else saleActive = !saleActive;
    }

    function gift(address[] calldata recipients) external onlyOwner {
        require(
            totalSupply() + recipients.length <= MAX_SUPPLY,
            "EXCEEDS_MAX_SUPPLY"
        );
        require(
            giftedAmount + recipients.length <= GIFT_SUPPLY,
            "EXCEEDS_GIFT_SUPPLY"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            giftedAmount++;
            _safeMint(recipients[i], totalSupply() + 1);
        }
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

    function setContractURI(string calldata URI) external onlyOwner notLocked {
        contractURI = URI;
    }

    function setBaseURI(string calldata URI) external onlyOwner notLocked {
        baseURI = URI;
    }

    function setProvenance(string calldata proof) external onlyOwner notLocked {
        provenance = proof;
    }

    function lockMetadata() external onlyOwner {
        locked = true;
    }

    // PUBLIC
    function mint(
        bytes32 hash,
        bytes memory signature,
        uint256 nonce,
        uint256 tokenQuantity
    ) external payable {
        require(saleActive, "SALE_CLOSED");
        require(
            totalSupply() + tokenQuantity <= MAX_SUPPLY,
            "EXCEEDS_MAX_SUPPLY"
        );
        require(tokenQuantity <= TX_LIMIT, "EXCEEDS_TX_LIMIT");
        require(tokenQuantity > 0, "NO_TOKENS_ISSUED");
        require(PRICE * tokenQuantity <= msg.value, "INCORRECT_ETH");
        require(matchSigner(hash, signature), "NO_DIRECT_MINT");
        require(!_usedNonces[msg.sender][nonce], "HASH_USED");
        require(
            hashTransaction(msg.sender, tokenQuantity, nonce) == hash,
            "HASH_FAIL"
        );

        _usedNonces[msg.sender][nonce] = true;
        for (uint256 i = 1; i <= tokenQuantity; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function presaleMint(
        bytes32 hash,
        bytes memory signature,
        uint256 nonce,
        uint256 tokenQuantity
    ) external payable {
        require(presaleActive && !saleActive, "PRESALE_CLOSED");
        require(
            totalSupply() + tokenQuantity <= MAX_SUPPLY,
            "EXCEEDS_MAX_SUPPLY"
        );
        require(
            tokenQuantity <= presaleTokensRemaining(msg.sender),
            "EXCEEDS_PRESALE_LIMIT"
        );
        require(tokenQuantity > 0, "NO_TOKENS_ISSUED");
        require(PRICE * tokenQuantity <= msg.value, "INCORRECT_ETH");
        require(matchSigner(hash, signature), "NO_DIRECT_MINT");
        require(!_usedNonces[msg.sender][nonce], "HASH_USED");
        require(
            hashTransaction(msg.sender, tokenQuantity, nonce) == hash,
            "HASH_FAIL"
        );

        presaleTokensClaimed[msg.sender] += tokenQuantity;
        _usedNonces[msg.sender][nonce] = true;
        for (uint256 i = 1; i <= tokenQuantity; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function presaleTokensRemaining(address addr)
        public
        view
        returns (uint256)
    {
        return PRESALE_LIMIT - presaleTokensClaimed[addr];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(tokenId), "NON_TOKEN");
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}