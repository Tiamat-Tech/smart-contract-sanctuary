// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract nonceHandler is ReentrancyGuard{
    mapping(bytes32 => uint256) public nonces;
    address private PLATFORM_ADDRESS;
    struct Sig {bytes32 r; bytes32 s; uint8 v;}
    event updatedNonce(address caller, address tokenAddress, uint256 tokenId, uint256 nonce);

    constructor(address platformAddress){
        PLATFORM_ADDRESS = platformAddress;
    }

    /**
     * @dev setNonce function
     * will be called when creating the item and when cancelling the item sale
     */
    function setNonce(address token, uint256 tokenId, Sig memory setNonceRSV) public nonReentrant {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(token,tokenId)), setNonceRSV), "Set nonce rsv is invalid!");
        nonces[getNonceKey(token, tokenId)] = getNonce(token, tokenId) + 1;

        emit updatedNonce(tx.origin, token, tokenId, getNonce(token, tokenId));
    }

    function getNonce(address token, uint256 tokenId) public view returns (uint) {
        return nonces[getNonceKey(token,tokenId)];
    }

    function getNonceKey(address token, uint256 tokenId) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(token, tokenId));
    }
        function verifySigner(address signer, bytes32 ethSignedMessageHash, Sig memory rsv) internal pure returns (bool)
    {
        return ECDSA.recover(ethSignedMessageHash, rsv.v, rsv.r, rsv.s ) == signer;
    }
        function messageHash(bytes memory abiEncode)internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abiEncode)));
    }
}