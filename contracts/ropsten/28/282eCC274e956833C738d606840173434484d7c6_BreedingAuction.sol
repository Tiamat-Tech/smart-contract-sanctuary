// SPDX-License-Identifier: MIT
// CryptoHero Contracts v1.0.0 (BreedingAuction.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./AuctionCore.sol";

/// @title Reverse auction modified for breeding
/// @notice We omit a fallback function to prevent accidental sends to this contract.
contract BreedingAuction is AuctionCore, IERC721Receiver {
    // Delegate constructor
    constructor(address _nftAddr) AuctionCore(_nftAddr) {}

    // @dev Sanity check that allows us to ensure that we are pointing to the
    //  right auction in our setBreedingAuctionAddress() call.
    function isBreedingAuction() external pure returns (bool) {
        return true;
    }

    /// @dev Creates and begins a new auction. Since this function is wrapped,require sender to be cryptoHero contract.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _price - Price (in wei) of item auction.
    /// @param _seller - Seller, if not the message sender
    function createAuction(
        uint256 _tokenId,
        uint256 _price,
        address _seller
    ) external override {
        // Sanity check that no inputs overflow how many bits we've allocated to store them in the auction struct.
        require(_price == uint256(uint128(_price)), "Price is invalid.");

        require(msg.sender == address(nonFungibleContract), "The msg.sender isn't contract");
        _escrow(_seller, _tokenId);
        Auction memory auction = Auction(_seller, uint128(_price), uint64(block.timestamp));
        _addAuction(_tokenId, auction);
    }

    /// @dev Places a bid for breeding. Requires the sender
    /// is the cryptoHero contract because all bid methods
    /// should be wrapped. Also returns the hero to the
    /// seller rather than the winner.
    function bid(uint256 _tokenId) external payable override {
        require(msg.sender == address(nonFungibleContract), "The msg.sender isn't contract");
        address seller = tokenIdToAuction[_tokenId].seller;
        // _bid checks that token ID is valid and will throw if bid fails
        _bid(_tokenId, msg.value);
        // We transfer the hero back to the seller, the winner will get the breeding right
        _transfer(seller, _tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}