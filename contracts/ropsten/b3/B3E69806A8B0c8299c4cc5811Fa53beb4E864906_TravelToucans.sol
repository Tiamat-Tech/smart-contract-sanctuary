// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

import "erc721a/contracts/ERC721A.sol";

/*
___________                         ._____________
\__    ___/___________ ___  __ ____ |  \__    ___/___  __ __   ____ _____    ____   ______
  |    |  \_  __ \__  \\  \/ // __ \|  | |    | /  _ \|  |  \_/ ___\\__  \  /    \ /  ___/
  |    |   |  | \// __ \\   /\  ___/|  |_|    |(  <_> )  |  /\  \___ / __ \|   |  \\___ \
  |____|   |__|  (____  /\_/  \___  >____/____| \____/|____/  \___  >____  /___|  /____  >
                      \/          \/                              \/     \/     \/     \/
*/

/// @author zkWheat
contract TravelToucans is ERC721A, Ownable {
    address private signer;

    bool public publicSaleActive;
    bool public preSaleActive;

    uint256 constant PRESALE_MAX_TX_PLUS_ONE = 5;
    uint256 constant PUBLIC_MAX_TX_PLUS_ONE = 23;
    uint256 public price = 0.022 ether;
    uint256 public upgradePrice = 0.032 ether;

    uint256 public MAX_SUPPLY_PLUS_ONE;

    constructor(string memory uri, address s, uint256 maxSupply) ERC721A("Travel Toucans", "TOUC"){
        _baseTokenURI = uri;
        signer = s;
        MAX_SUPPLY_PLUS_ONE = maxSupply;
    }

    function publicMint(uint256 amount, bool upgrade) public payable {
        require(publicSaleActive, "sale inactive");
        require(amount < PUBLIC_MAX_TX_PLUS_ONE, "only 22 per tx");
        require(totalSupply() + amount < MAX_SUPPLY_PLUS_ONE, "exceeds max supply");
        if (upgrade) {
            require(amount * upgradePrice == msg.value, "ETH incorrect");
        } else {
            require(amount * price == msg.value, "ETH incorrect");
        }

        _safeMint(msg.sender, amount);
    }


    function presale(uint256 amount, bool upgrade, bytes memory signature) public payable {
        require(preSaleActive, "presale inactive");
        require(totalSupply() + amount < MAX_SUPPLY_PLUS_ONE, "exceeds max supply");
        require(isPreListed(msg.sender, signature), "invalid signature");
        require(numberMinted(msg.sender) + amount < PRESALE_MAX_TX_PLUS_ONE, "exceeds presale allotment");

        if (upgrade) {
            require(amount * upgradePrice == msg.value, "ETH incorrect");
        } else {
            require(amount * price == msg.value, "ETH incorrect");
        }

        _safeMint(msg.sender, amount);
    }

    function freeMint(uint256 amount, bytes memory signature) public {
        require(preSaleActive, "presale inactive");
        require(totalSupply() + amount < MAX_SUPPLY_PLUS_ONE, "exceeds max supply");
        require(isFreeListed(msg.sender, true, amount, signature), "invalid signature");
        require(numberMinted(msg.sender) < amount, "free mint claimed");

        _safeMint(msg.sender, amount);
    }

    // For marketing etc.
    function devMint(uint256 amount) external onlyOwner {
        require(totalSupply() + amount < MAX_SUPPLY_PLUS_ONE, "exceeds max supply");
        _safeMint(msg.sender, amount);
    }

    function airdrop(address[] calldata addresses) external onlyOwner {
        require(addresses.length < MAX_SUPPLY_PLUS_ONE, "exceeds max supply");
        for (uint256 i = 0; i < addresses.length; i++) {
            _safeMint(addresses[i], 1);
        }
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function isPreListed(address user, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(user));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == signer;
    }

    function isFreeListed(address user, bool free, uint256 amount, bytes memory signature) public view returns (bool) {
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

    function withdraw(address payable _recipient) external onlyOwner {
        _recipient.transfer(address(this).balance);
    }

    function setPrice(uint256 _price) public onlyOwner() {
        price = _price;
    }

    function setUpgradePrice(uint256 _upgradePrice) public onlyOwner() {
        upgradePrice = _upgradePrice;
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function flipPublicSale() public onlyOwner {
        publicSaleActive = !publicSaleActive;
    }

    function flipPreSale() public onlyOwner {
        preSaleActive = !preSaleActive;
    }

    // // metadata URI
    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
}