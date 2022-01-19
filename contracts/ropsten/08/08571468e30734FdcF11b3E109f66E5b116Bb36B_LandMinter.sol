// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./Land.sol";

contract LandMinter {
    using ECDSA for bytes32;

    Land public nftAddress;
    ContractControlList internal contractControlList;

    constructor(address nftAddress_, ContractControlList contractControlList_) {
        nftAddress = Land(nftAddress_);
        contractControlList = contractControlList_;
    }

    /**
    * @notice Recreates message from backend and returns its hash.
    */
    function _createMessageHash(address tokenAddress, uint256 tokenId) pure internal returns (bytes32) {
        return keccak256(abi.encodePacked(tokenAddress, tokenId));
    }

    /**
    * @notice Returns address of message signer.
    */
    function _getSigner(bytes32 messageHash, bytes memory signature) pure internal returns (address) {
        return messageHash
        .toEthSignedMessageHash()
        .recover(signature);
    }

    /**
     * @dev Payable public function which allows user to buy tokens, by sending particular amount of ETH.
     * @param tokenId - tokenId which user wants to mint
     *
     */
    function mintToken(uint256 tokenId, bytes memory signature) external {
        bytes32 messageHash = _createMessageHash(address(nftAddress), tokenId);
        address signer = _getSigner(messageHash, signature);

        require(contractControlList.hasRole(contractControlList.LAND_MINTER_ROLE(), signer), "Message signer has no minter role");

        nftAddress.mintTo(msg.sender, tokenId);
    }
}