// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "./ERC721.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
___________                         ._____________
\__    ___/___________ ___  __ ____ |  \__    ___/___  __ __   ____ _____    ____   ______
  |    |  \_  __ \__  \\  \/ // __ \|  | |    | /  _ \|  |  \_/ ___\\__  \  /    \ /  ___/
  |    |   |  | \// __ \\   /\  ___/|  |_|    |(  <_> )  |  /\  \___ / __ \|   |  \\___ \
  |____|   |__|  (____  /\_/  \___  >____/____| \____/|____/  \___  >____  /___|  /____  >
                      \/          \/                              \/     \/     \/     \/
*/

/// @author nftley
contract TravelToucans is ERC721, Ownable {
    using Strings for uint256;
    address private signer;
    address private burner;

    bool public publicSaleActive;

    uint256 constant PRESALE_MAX_TX_PLUS_ONE = 3;
    uint256 constant PUBLIC_MAX_TX_PLUS_ONE = 6;
    uint256 public price = 0.022 ether;
    uint256 public upgradePrice = 0.032 ether;

    string public baseURI;
    uint256 public MAX_SUPPLY_PLUS_ONE;

    mapping(address => uint256) private presaleWalletLimits;
    mapping(address => uint256) private mainsaleWalletLimits;
    mapping(address => uint256) private freeWalletLimits;

    constructor(string memory uri, address s, uint256 maxSupply) ERC721("Travel Toucans", "TravelToucans"){
        baseURI = uri;
        signer = s;
        MAX_SUPPLY_PLUS_ONE = maxSupply;
    }

    function airdrop(address[] calldata airdropAddresses) public onlyOwner {
        require(airdropAddresses.length < MAX_SUPPLY_PLUS_ONE, "Mint would exceed max supply of Toucans");
        for (uint256 i = 0; i < airdropAddresses.length; i++) {
            _mint(airdropAddresses[i], totalSupply);
        }
    }

    function publicMint(uint256 amount, bool upgrade) public payable {
        require(publicSaleActive, "Sale must be active to mint a Toucan");
        require(amount < PUBLIC_MAX_TX_PLUS_ONE, "Can only mint 5 toucans at a time");
        require(totalSupply + amount < MAX_SUPPLY_PLUS_ONE, "Mint would exceed max supply of Toucans");
        if (upgrade) {
            require(amount * upgradePrice == msg.value, "Ether value sent is not correct");
        } else {
            require(amount * price == msg.value, "Ether value sent is not correct");
        }
        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }


    function presale(uint256 amount, bool upgrade, bytes memory signature) public payable {
        require(!publicSaleActive, "Presale is over");
        require(totalSupply + amount < MAX_SUPPLY_PLUS_ONE, "Mint would exceed max supply of Toucans");
        require(isListed(msg.sender, false, amount, signature), "Invalid signature provided for presale list");
        require(presaleWalletLimits[msg.sender] + amount < PRESALE_MAX_TX_PLUS_ONE, "Exceeds presale supply");
        if (upgrade) {
            require(amount * upgradePrice == msg.value, "Ether value sent is not correct");
        } else {
            require(amount * price == msg.value, "Ether value sent is not correct");
        }

        presaleWalletLimits[msg.sender] += amount;
        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function freeMint(uint256 amount, bytes memory signature) public {
        require(!publicSaleActive, "Free mint period is over");
        require(totalSupply + amount < MAX_SUPPLY_PLUS_ONE, "Mint would exceed max supply of Toucans");
        require(isListed(msg.sender, true, amount, signature), "Invalid signature provided for free mint");
        require(freeWalletLimits[msg.sender] == 0, "Free mint is already claimed");

        freeWalletLimits[msg.sender] += amount;

        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function isListed(address user, bool free, uint256 amount, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(user, free, amount));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }

    function getEthSignedMessageHash(bytes32 _messageHash) private pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
        keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "sig invalid");

        assembly {
        /*
        First 32 bytes stores the length of the signature

        add(sig, 32) = pointer of sig + 32
        effectively, skips first 32 bytes of signature

        mload(p) loads next 32 bytes starting at the memory address p into memory
        */

        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function burn(uint tokenId) public {
        require(msg.sender == burner, "Not authorized");
        _burn(tokenId);
    }

    function withdraw(address payable recipient) external onlyOwner {
        recipient.transfer(address(this).balance);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function setPrice(uint256 _price) public onlyOwner() {
        price = _price;
    }

    function setUpgradePrice(uint256 _upgradePrice) public onlyOwner() {
        upgradePrice = _upgradePrice;
    }

    function setBurner(address _burner) public onlyOwner {
        burner = _burner;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function flipSaleState() public onlyOwner {
        publicSaleActive = !publicSaleActive;
    }
}