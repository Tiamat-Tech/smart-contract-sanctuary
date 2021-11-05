// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./NFT.sol";

contract XIOCustodian {
    using SafeMath for uint256;

    mapping(uint256 => uint256) public tokenBalances;

    // These could be made constant
    address public erc20TokenAddress;
    address public nftTokenAddress;

    // Define the constructor
    constructor(address _erc20TokenAddress, address _nftTokenAddress) {
        erc20TokenAddress = _erc20TokenAddress;
        nftTokenAddress = _nftTokenAddress;
    }

    function balanceOf(uint256 nftId) public view returns (uint256) {
        return tokenBalances[nftId];
    }

    // This will allow anyone to deposit some amount of XIO 'into' a given NFT.
    function deposit(uint256 nftId, uint256 tokenAmount) public {
        // Check if the nftID is valid
        require(NFT(nftTokenAddress).exists(nftId), "NFT DOES NOT EXIST");

        // Transfer tokenAmount
        IERC20(erc20TokenAddress).transferFrom(msg.sender, address(this), tokenAmount);

        // Update tokenBalances
        tokenBalances[nftId] = tokenBalances[nftId].add(tokenAmount);
    }

    // The same as deposit but allows in bulk
    function bulkDeposit(uint256[] memory nftIds, uint256[] memory tokenAmounts) public returns (bool) {
        require(nftIds.length == tokenAmounts.length, "ARRAY SIZE MISMATCH");

        for (uint256 i = 0; i < nftIds.length; i++) {
            deposit(nftIds[i], tokenAmounts[i]);
        }

        return true;
    }

    // Allow only the owner of the NFT to withdraw 'from' the NFT
    function withdrawAll(uint256 nftId) public returns (bool) {
        // Get the owner
        address ownerOfNft = NFT(nftTokenAddress).ownerOf(nftId);

        // Ensure only the owner calls this function
        require(msg.sender == ownerOfNft, "NOT OWNER");

        // Burn the NFT
        NFT(nftTokenAddress).burn(nftId);

        // Get the full balance owed to this NFT
        uint256 amountOfTokens = tokenBalances[nftId];

        // Transfer the owned balance to the owner of this NFT
        if (amountOfTokens > 0) {
            IERC20(erc20TokenAddress).transfer(ownerOfNft, amountOfTokens);
        }

        // Update the tokenBalances
        tokenBalances[nftId] = 0;

        return true;
    }
}