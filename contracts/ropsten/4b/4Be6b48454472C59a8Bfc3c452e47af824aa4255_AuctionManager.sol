// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionManager is Ownable, ReentrancyGuard {

    struct Auction {
        string buyerId;
        string editionId;
        string itemId;
        uint256 price;
        address payable ownerWallet;
        address payable artistWallet;
        uint256 artistRoyalty;
    }

    uint256 public constant FEEDOMINATOR = 10000;

    address payable public vaultWallet;
    uint32 public vaultFee = 500;
    
    address public signer;
    string public salt = "\x19Ethereum Signed Message:\n32";

    event BuyAuctionItem(
        string _buyerId, 
        string _editionId, 
        string _itemId,
        uint256 _price,
        address _ownerWallet,
        address _artistWallet,
        uint256 _artistRoyalty
    );

    constructor(address payable _vaultWallet, address _signer) {
        require(_vaultWallet != address(0), "Invalid vault address");
        vaultWallet = _vaultWallet;
        signer = _signer;
    }

    function buyAuctionItem(
        Auction calldata _auction,
        bytes calldata _signature
    ) external payable nonReentrant {
        require(msg.value == _auction.price, "Wrong price");
        require(verify(_auction, _signature) == true, "Invalid signature");

        uint256 vault = msg.value * vaultFee / FEEDOMINATOR;
        uint256 artist = msg.value * _auction.artistRoyalty / FEEDOMINATOR;

        uint256 payout = msg.value - vault - artist;
        require(payout >= 0, "Invalid vaultFee or ArtistRoyalty");

        _auction.ownerWallet.transfer(payout);
        _auction.artistWallet.transfer(artist);

        vaultWallet.transfer(vault);

        emit BuyAuctionItem(_auction.buyerId, _auction.editionId, _auction.itemId, _auction.price, _auction.ownerWallet, _auction.artistWallet, _auction.artistRoyalty);
    }

    /* ========== Signature ========== */
    function getMessageHash (Auction calldata _auction) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_auction.buyerId, _auction.editionId, _auction.itemId, _auction.ownerWallet, _auction.artistWallet, _auction.artistRoyalty));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public view returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked(salt, _messageHash));
    }

    function verify(
        Auction calldata _auction,
        bytes calldata _signature
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(_auction);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, _signature) == signer;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public pure returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public pure returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "invalid signature length");

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

    /* ========== RESTRICTED FUNCTIONS ========== */
    function setVaultAddress(address payable _vaultWallet) external onlyOwner {
        require(_vaultWallet != address(0), "Invalid vault address");
        
        vaultWallet = _vaultWallet;
    }

    function setVaultFee(uint32 _fee) external onlyOwner {
        vaultFee = _fee;
    }

    function setSalt(string memory _salt) external onlyOwner {
        salt = _salt;
    }

    function setSignerAddress(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid address");
        
        signer = _signer;
    }

}