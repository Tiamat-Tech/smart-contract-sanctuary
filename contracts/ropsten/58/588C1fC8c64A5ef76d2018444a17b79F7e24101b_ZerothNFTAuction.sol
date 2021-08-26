// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

library LibNFTAuction {

    event AuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 endsAt);

    struct Product {
        IERC721 nftContract;
        uint256 tokenId;
    }

    struct Bid {
        address payable bidder;
        uint256 amount;
    }

    struct Auction {
        uint256 id;
        Product product;
        address payable seller;
        uint256 duration;
        uint256 extensionDuration;
        uint256 endsAt;
        uint256 fixedPrice;
        Bid currentBid;
    }

    function getSeller(Auction storage auction) internal view returns (address) {
        address seller = auction.seller;
        if (seller == address(0)) {
            Product memory product = auction.product;
            return product.nftContract.ownerOf(product.tokenId);
        }
        return seller;
    }
}