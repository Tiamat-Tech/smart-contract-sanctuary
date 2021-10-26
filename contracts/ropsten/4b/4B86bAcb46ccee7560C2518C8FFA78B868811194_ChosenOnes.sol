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
import "./Mintable.sol";

contract ChosenOnes is ERC721Enumerable, Ownable, Mintable {
    using Strings for uint256;
    using ECDSA for bytes32;

    event Mint(address indexed _to, uint256 indexed _id);

    address public constant SIGNER = 0x78dF3aC8Bb88eF068A5A0D709f53Dedbd9D1964d;
    address public constant VAULT = 0xDDA119Aa6Da912C62428a5A37Ed5541CB87e32a7;

    uint256 public supply;
    uint256 public giftedAmount;
    uint256 public saleStart;
    uint256 public presaleStart;
    uint256 public presaleEnd;
    string public baseURI;
    string public provenance;

    mapping(address => uint256) public presaleTokensClaimed;
    mapping(address => mapping(uint256 => bool)) private _usedNonces;

    constructor(address _owner, address _imx)
        ERC721("ChosenOnes", "ONES")
        Mintable(_owner, _imx)
    {}

    // INTERNAL
    function _mintFor(
        address to,
        uint256 id,
        bytes memory blueprint
    ) internal override {
        _safeMint(to, id);
    }

    function _hashTransaction(
        address sender,
        uint256 qty,
        uint256 nonce
    ) private pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(sender, qty, nonce))
                .toEthSignedMessageHash();
    }

    function _matchSigner(bytes32 hash, bytes memory signature)
        private
        pure
        returns (bool)
    {
        return SIGNER == hash.recover(signature);
    }

    // ONLY OWNER
    function setSale(
        uint256 start,
        uint256 preStart,
        uint256 preEnd
    ) external onlyOwner {
        saleStart = start;
        presaleStart = preStart;
        presaleEnd = preEnd;
    }

    function gift(address[] calldata recipients) external onlyOwner {
        require(supply + recipients.length <= 11111, "Exceeds max supply");
        require(giftedAmount + recipients.length <= 444, "Exceeds gift supply");
        for (uint256 i = 0; i < recipients.length; i++) {
            emit Mint(msg.sender, supply + 1);
            supply++;
            giftedAmount++;
        }
    }

    function withdraw() external onlyOwner {
        payable(VAULT).transfer(address(this).balance);
    }

    function setBaseURI(string calldata URI) external onlyOwner {
        baseURI = URI;
    }

    function setProvenance(string calldata proof) external onlyOwner {
        provenance = proof;
    }

    // PUBLIC
    function mint(uint256 tokenQuantity) external payable {
        require(block.timestamp >= saleStart, "Sale closed");
        require(supply + tokenQuantity <= 11111, "Exceeds max supply");
        require(tokenQuantity <= 15, "Exceeds transaction limit");
        require(tokenQuantity > 0, "No tokens issued");
        require(msg.value >= 0.1 ether * tokenQuantity, "Insufficient ETH");

        for (uint256 i = 0; i < tokenQuantity; i++) {
            emit Mint(msg.sender, supply + 1);
            supply++;
        }
    }

    function presaleMint(
        bytes32 hash,
        bytes memory signature,
        uint256 nonce,
        uint256 tokenQuantity
    ) external payable {
        require(
            block.timestamp >= presaleStart && block.timestamp < presaleEnd,
            "Presale closed"
        );
        require(supply + tokenQuantity <= 5555, "Exceeds presale supply");
        require(
            tokenQuantity <= 5 - presaleTokensClaimed[msg.sender],
            "Exceeds presale limit"
        );
        require(tokenQuantity > 0, "No tokens issued");
        require(msg.value >= 0.1 ether * tokenQuantity, "Insufficient ETH");
        require(_matchSigner(hash, signature), "No direct mint");
        require(!_usedNonces[msg.sender][nonce], "Hash used");
        require(
            _hashTransaction(msg.sender, tokenQuantity, nonce) == hash,
            "Hash fail"
        );

        presaleTokensClaimed[msg.sender] += tokenQuantity;
        _usedNonces[msg.sender][nonce] = true;
        for (uint256 i = 0; i < tokenQuantity; i++) {
            emit Mint(msg.sender, supply + 1);
            supply++;
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }
}