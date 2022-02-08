// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AuctionManager is Ownable, ReentrancyGuard {

    struct Auction {
        string buyerId;
        uint256 editionId;
        uint256 itemId;
        uint256 price;
        address payable ownerWallet;
        address payable artistWallet;
        uint256 artistRoyalty;
    }

    uint256 public constant FEEDOMINATOR = 10000;
    uint8 constant AUCTION_NOT_STARTED = 0;
    uint8 constant AUCTION_IN_PROGRESS = 1;

    address payable public vaultWallet;
    uint32 public vaultFee = 500;
    
    address public signer;
    string public salt = "\x19Ethereum Signed Message:\n32";

    mapping(uint256 => mapping(uint256 => uint8)) public auctionItemStatus;  // 0: not started, 1: in progress

    event AuctionStarted (
        string ownerId,
        uint256 editionId,
        uint256 itemId
    );

    event BuyAuctionItem(
        string buyerId, 
        uint256 editionId, 
        uint256 itemId,
        uint256 price,
        address ownerWallet,
        address artistWallet,
        uint256 artistRoyalty
    );

    constructor(address payable _vaultWallet, address _signer) {
        require(_vaultWallet != address(0), "Invalid vault address");
        vaultWallet = _vaultWallet;
        signer = _signer;
    }

    function startAuction(string calldata ownerId, uint256 editionId, uint itemId, bytes calldata signature) external {
        require(auctionItemStatus[editionId][itemId] == AUCTION_NOT_STARTED, "Item is already in Auction");

        bytes32 messageHash = keccak256(abi.encodePacked(ownerId, editionId, itemId));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(salt, messageHash));
        bool verify = recoverSigner(ethSignedMessageHash, signature) == signer;

        require(verify == true, "Start auction: Invalid signature");

        auctionItemStatus[editionId][itemId] = AUCTION_IN_PROGRESS;

        AuctionStarted(ownerId, editionId, itemId);
    }

    function buyAuctionItem(
        Auction calldata auction,
        bytes calldata signature,
        uint256 deadline
    ) external payable nonReentrant {
        require(block.timestamp < deadline, "Transaction is expired");

        require(auctionItemStatus[auction.editionId][auction.itemId] == AUCTION_IN_PROGRESS, "Item is not available for Auction");

        require(msg.value == auction.price, "Wrong price");

        {
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    auction.buyerId,
                    auction.editionId,
                    auction.itemId,
                    auction.ownerWallet,
                    auction.artistWallet,
                    auction.artistRoyalty,
                    deadline
                )
            );
            bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(salt, messageHash));
            bool verify = recoverSigner(ethSignedMessageHash, signature) == signer;

            require(verify == true, "Buy Auction: Invalid signature");
        }
        
        {
            uint256 vault = msg.value * vaultFee / FEEDOMINATOR;
            uint256 artist = msg.value * auction.artistRoyalty / FEEDOMINATOR;

            uint256 payout = msg.value - vault - artist;
            require(payout >= 0, "Invalid vaultFee or ArtistRoyalty");

            auction.ownerWallet.transfer(payout);
            auction.artistWallet.transfer(artist);

            vaultWallet.transfer(vault);
        }

        auctionItemStatus[auction.editionId][auction.itemId] = AUCTION_NOT_STARTED;

        emit BuyAuctionItem(
            auction.buyerId,
            auction.editionId,
            auction.itemId,
            auction.price,
            auction.ownerWallet,
            auction.artistWallet,
            auction.artistRoyalty
        );
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        internal pure returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal pure returns (bytes32 r, bytes32 s, uint8 v)
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

    /* ========== Signature ========== */
    // function getMessageHash (Auction calldata _auction) public pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(_auction.buyerId, _auction.editionId, _auction.itemId, _auction.price, _auction.ownerWallet, _auction.artistWallet, _auction.artistRoyalty));
    // }

    // function getEthSignedMessageHash(bytes32 _messageHash) public view returns (bytes32) {
    //     /*
    //     Signature is produced by signing a keccak256 hash with the following format:
    //     "\x19Ethereum Signed Message\n" + len(msg) + msg
    //     */
    //     return keccak256(abi.encodePacked(salt, _messageHash));
    // }
}