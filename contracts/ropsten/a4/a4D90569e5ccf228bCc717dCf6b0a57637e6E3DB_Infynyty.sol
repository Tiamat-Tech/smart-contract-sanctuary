// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./nonceHandler.sol";
import "./transferNFTHandler.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Infynyty is ReentrancyGuard, Ownable{
    address ERC1155Address;
    address nonceHandlerAddress;
    address nftTransferAddress;
    address platformAddress;
    mapping(address => bool) adminStatus;
    
    struct Sig {bytes32 r; bytes32 s; uint8 v;}

    struct ERC1155Struct{
        address seller;
        uint256 tokenId;
        address NFTAddress;
        uint256 nonce;
        uint256 listingPrice;
        uint256 amount;
    }
    event Sell(address seller, uint256 tokenId, address NFTAddress, uint256 nonce, uint256 listingPrice, string desc);

    constructor(address setERC1155Addr, address nonceHandlerAddr, address nftTransferAddr, address platformAddr) {
        ERC1155Address = setERC1155Addr;
        nonceHandlerAddress = nonceHandlerAddr;
        nftTransferAddress = nftTransferAddr;
        platformAddress = platformAddr;
        adminStatus[msg.sender] = true;
    }
    /**
     * @dev 
     * Need Review: kira-kira butuh rsv lagi ngga buat manggil fungsi sell ?
     * Untuk sekarang rsv hanya buat nge setNonce
     */
    function sell(ERC1155Struct memory nftInfo, nonceHandler.Sig memory sellNonceRSV, Sig memory sellRSV) public nonReentrant {
        require(verifySigner(platformAddress, messageHash(abi.encodePacked(nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, nftInfo.nonce)), sellRSV), "Sell rsv invalid");
        require(msg.sender == nftInfo.seller, "You are not a seller");
        nonceHandler(nonceHandlerAddress).setNonce(nftInfo.NFTAddress, nftInfo.tokenId, sellNonceRSV);
        emit Sell(nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, nftInfo.nonce, nftInfo.listingPrice, "NFT Set to Sell");
    }
    function cancelSell(ERC1155Struct memory nftInfo, nonceHandler.Sig memory cancelSellNonceRSV, Sig memory cancelRSV) public nonReentrant {
        require(verifySigner(platformAddress, messageHash(abi.encodePacked(nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, nftInfo.nonce)), cancelRSV), "Cancel rsv invalid");
        require(msg.sender == nftInfo.seller, "You are not a owner of this nft.");
        nonceHandler(nonceHandlerAddress).setNonce(nftInfo.NFTAddress, nftInfo.tokenId, cancelSellNonceRSV);
        emit Sell(nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, nftInfo.nonce, nftInfo.listingPrice, "NFT sell cancelled");
    }
    function buy(ERC1155Struct memory nftInfo, Sig memory sellerRSV, Sig memory buyerRSV) public payable nonReentrant {
        require(verifySigner(platformAddress, messageHash(abi.encodePacked(nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, nftInfo.nonce, msg.value, nftInfo.amount)), sellerRSV), "Seller RSV Invalid");
        require(verifySigner(platformAddress, messageHash(abi.encodePacked(msg.sender, nftInfo.seller, nftInfo.tokenId, nftInfo.NFTAddress, msg.value, nftInfo.amount)), buyerRSV), "Buyer RSV Invalid");
        payable(nftInfo.seller).transfer(msg.value);
        TransferNFT(nftTransferAddress).transferERC1155(nftInfo.NFTAddress, nftInfo.seller, msg.sender, nftInfo.tokenId, nftInfo.tokenId);

    }
    function tranferOwner(address newOwner) public onlyOwner{
        _transferOwnership(newOwner);
    }
    function addAdmin(address newAdmin) public onlyOwner{
        adminStatus[newAdmin] = true;
    }
    function revokeAdmin(address revokedAdmin) public onlyOwner{
        adminStatus[revokedAdmin] = false;
    }

    function changeMarketInfo(address newERC1155Addr, address newNonceHandlerAddr, address newNftTransferAddr, address newPlatformAddress) public onlyAdmin{
        if(newERC1155Addr != address(0)){
            ERC1155Address = newERC1155Addr;
        }if(newNftTransferAddr != address(0)){
            nftTransferAddress = newNftTransferAddr;
        }if(newNonceHandlerAddr != address(0)){
            nonceHandlerAddress = newNonceHandlerAddr;
        }if(newPlatformAddress != address(0)){
            platformAddress = newPlatformAddress;
        }
    }
    function verifySigner(address signer, bytes32 ethSignedMessageHash, Sig memory rsv) internal pure returns (bool)
    {
        return ECDSA.recover(ethSignedMessageHash, rsv.v, rsv.r, rsv.s ) == signer;
    }
    function messageHash(bytes memory abiEncode)internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abiEncode)));
    } 

    modifier onlyAdmin(){
        require(adminStatus[msg.sender], "You're not an admin.");
        _;
    } 
    
}