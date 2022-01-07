// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "./ERC721.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

    error SoldOut();
    error SaleClosed();
    error InvalidMintParameters();
    error MintingTooMany();
    error NotWhitelisted();
    error NotFreelisted();
    error NotAuthorized();

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
    address private passwordSigner;
    address private freeSigner;
    address private toucanBurner;

    bool publicSaleActive;

    uint256 constant PRESALE_MAX_TX = 2;
    uint256 constant PUBLIC_MAX_TX = 5;
    uint256 constant public MAX_SUPPLY = 10001;
    uint256 private _price = 0.022 ether;
    uint256 private _upgradePrice = 0.032 ether;

    string public baseURI;

    mapping (address => uint256) private presaleWalletLimits;
    mapping (address => uint256) private mainsaleWalletLimits;
    mapping (address => uint256) private freeWalletLimits;

    constructor(string memory initialBaseURI, address initialPasswordSigner, address _freeSigner) ERC721("Travel Toucans", "TravelToucans"){
        baseURI = initialBaseURI;
        passwordSigner = initialPasswordSigner;
        freeSigner = _freeSigner;
    }

    function setPrice(uint256 _newPrice) public onlyOwner() {
        _price = _newPrice;
    }

    function setUpgradePrice(uint256 _newPrice) public onlyOwner() {
        _upgradePrice = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function airdrop(address[] calldata airdropAddresses) public onlyOwner {
        for(uint256 i = 0; i < airdropAddresses.length; i++) {
            _mint(airdropAddresses[i], totalSupply);
        }
    }

    function setToucanBurner(address newToucanBurner) public onlyOwner {
        toucanBurner = newToucanBurner;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function setPasswordSigner(address signer) public onlyOwner {
        passwordSigner = signer;
    }

    function setPublicSale(bool publicSale) public onlyOwner {
        publicSaleActive = publicSale;
    }

    function purchase(uint256 amount) public payable {
        if(!publicSaleActive) revert SaleClosed();
        if(totalSupply + amount > MAX_SUPPLY) revert SoldOut();
        if(mainsaleWalletLimits[msg.sender] + amount > PUBLIC_MAX_TX || msg.value < _price * amount) revert InvalidMintParameters();

        mainsaleWalletLimits[msg.sender] += amount;
        for(uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function purchaseUpgrade(uint256 amount) public payable {
        if(!publicSaleActive) revert SaleClosed();
        if(totalSupply + amount > MAX_SUPPLY) revert SoldOut();
        if(mainsaleWalletLimits[msg.sender] + amount > PUBLIC_MAX_TX || msg.value < _upgradePrice * amount) revert InvalidMintParameters();

        mainsaleWalletLimits[msg.sender] += amount;
        for(uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function presale(uint256 amount, bytes memory signature) public payable {
        if(publicSaleActive) revert SaleClosed();
        if(totalSupply + amount > MAX_SUPPLY) revert SoldOut();
        if(!isWhitelisted(msg.sender, signature)) revert NotWhitelisted();
        if(presaleWalletLimits[msg.sender] + amount > PRESALE_MAX_TX || msg.value < _price * amount) revert InvalidMintParameters();

        presaleWalletLimits[msg.sender] += amount;
        for(uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function presaleUpgrade(uint256 amount, bytes memory signature) public payable {
        if(publicSaleActive) revert SaleClosed();
        if(totalSupply + amount > MAX_SUPPLY) revert SoldOut();
        if(!isWhitelisted(msg.sender, signature)) revert NotWhitelisted();
        if(presaleWalletLimits[msg.sender] + amount > PRESALE_MAX_TX || msg.value < _upgradePrice * amount) revert InvalidMintParameters();

        presaleWalletLimits[msg.sender] += amount;
        for(uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, totalSupply);
        }
    }

    function freeMint(bytes memory signature) public {
        if(publicSaleActive) revert SaleClosed();
        if(totalSupply + 1 > MAX_SUPPLY) revert SoldOut();
        if(!isFreelisted(msg.sender, signature)) revert NotFreelisted();
        if(freeWalletLimits[msg.sender] > 0) revert InvalidMintParameters();

        freeWalletLimits[msg.sender] += 1;
        _mint(msg.sender, totalSupply);
    }

    function withdraw(address payable recipient) external onlyOwner {
        recipient.transfer(address(this).balance);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function isWhitelisted(address user, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(user));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == passwordSigner;
    }

    function isFreelisted(address user, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(user));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == freeSigner;
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
        if(msg.sender != toucanBurner) revert NotAuthorized();
        _burn(tokenId);
    }
}