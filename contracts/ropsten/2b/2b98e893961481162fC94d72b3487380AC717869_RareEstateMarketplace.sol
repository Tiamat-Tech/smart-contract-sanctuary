// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract RareEstateMarketplace {
    struct EstateForSale {
        uint256 id;
        address tokenAddress;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool isSelling;
    }

    EstateForSale[] public saleEstates;

    //  Token address => TokenId => isSelling
    mapping(address => mapping(uint256 => bool)) activeItems;

    event EstateAdded(
        uint256 saleId,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        address seller
    );
    event EstateSold(
        uint256 saleId,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        address seller,
        address buyer
    );

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender);
        _;
    }

    modifier HasTransferApproval(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.getApproved(tokenId) == address(this));
        _;
    }

    modifier EstateExists(uint256 id) {
        require(
            id < saleEstates.length && saleEstates[id].id == id,
            "Could not find item"
        );
        _;
    }

    modifier IsSelling(uint256 id) {
        require(saleEstates[id].isSelling, "Not for sale");
        _;
    }

    function addItemToMarket(
        uint256 tokenId,
        address tokenAddress,
        uint256 price
    )
        external
        OnlyItemOwner(tokenAddress, tokenId)
        HasTransferApproval(tokenAddress, tokenId)
        returns (uint256)
    {
        require(!activeItems[tokenAddress][tokenId], "Already up for sale");
        uint256 newItemId = saleEstates.length;
        saleEstates.push(
            EstateForSale(
                newItemId,
                tokenAddress,
                tokenId,
                payable(msg.sender),
                price,
                true
            )
        );
        activeItems[tokenAddress][tokenId] = true;

        assert(saleEstates[newItemId].id == newItemId);
        emit EstateAdded(newItemId, tokenId, tokenAddress, price, msg.sender);
        return newItemId;
    }

    function buyItem(uint256 id)
        external
        payable
        EstateExists(id)
        IsSelling(id)
        HasTransferApproval(
            saleEstates[id].tokenAddress,
            saleEstates[id].tokenId
        )
    {
        require(msg.value >= saleEstates[id].price, "Not enough funds sent");
        require(msg.sender != saleEstates[id].seller);

        EstateForSale memory _item = saleEstates[id];

        saleEstates[id].isSelling = false;
        activeItems[_item.tokenAddress][_item.tokenId] = false;

        IERC721(_item.tokenAddress).safeTransferFrom(
            _item.seller,
            msg.sender,
            _item.tokenId
        );
        _item.seller.transfer(msg.value);
        emit EstateSold(
            id,
            _item.tokenId,
            _item.tokenAddress,
            _item.price,
            _item.seller,
            msg.sender
        );
    }
}