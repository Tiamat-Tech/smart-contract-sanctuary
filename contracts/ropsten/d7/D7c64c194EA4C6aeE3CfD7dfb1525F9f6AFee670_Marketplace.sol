// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Marketplace/IERC721.sol";

/**
 * @title Marketplace contract
 */
contract Marketplace {
    receive() external payable {}
    fallback() external payable {}

    event Post (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price
    );

    event Cancel (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address owner
    );

    event Sale (
        uint256 itemId,
        address nftContract,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price
    );

    struct Item {
        uint itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        bool sold;
        bool cancelled;
    }

    mapping(uint256 => Item) private _tracking;

    uint256 private _itemId;

    bool private constant unlocked = true;
    bool private constant locked = false;
    bool private _gate;

    /**
     * @dev Sets initial values for {_gate} to {_itemId}
     */
    constructor() {
        _gate = unlocked;
        _itemId = 1000000000;
    }

    /**
     * @dev Posts an item onto the marketplace
     */
    function post(address nftContract, uint256 tokenId, uint256 price) public {
        require(_gate != locked, "Marketplace: reentrancy denied");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Marketplace: caller is not the owner of the token");
        require(IERC721(nftContract).getApproved(tokenId) == address(this), "Marketplace: market has not been approved");
        require(price > 0, "Marketplace: price cannot be zero");

        _gate = locked;

        _itemId += 1;
        uint256 itemId = _itemId;

        _tracking[itemId] = Item (
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            msg.sender,
            price,
            false,
            false
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit Post(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            msg.sender,
            price
        );

        _gate = unlocked;
    }

    function cancel(uint256 itemId) public {
        require(_gate != locked, "Marketplace: reentrancy denied");
        require(_tracking[itemId].sold == false, "Marketplace: item already has been sold");
        require(_tracking[itemId].owner == msg.sender, "Marketplace: not an owner");
        require(_tracking[itemId].cancelled == false, "Marketplace: item already cancelled");

        _gate = locked;

        address nftContract = _tracking[itemId].nftContract;
        uint256 tokenId = _tracking[itemId].tokenId;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        _tracking[itemId].cancelled = true;

        emit Cancel(
            itemId,
            nftContract,
            tokenId,
            msg.sender
        );

        _gate = unlocked;
    }

    /**
     * @dev Fetches an item on the marketplace
     */
    function fetch(uint256 itemId) public view returns (address, uint256, address, address, uint256, bool, bool) {
        return (
            _tracking[itemId].nftContract,
            _tracking[itemId].tokenId,
            _tracking[itemId].seller,
            _tracking[itemId].owner,
            _tracking[itemId].price,
            _tracking[itemId].sold,
            _tracking[itemId].cancelled
        );
    }

    /**
     * @dev Sells an item for sale on the marketplace
     */
    function buy(uint256 itemId) public payable {
        require(_gate != locked, "Marketplace: reentrancy denied");
        require(_tracking[itemId].sold == false, "Marketplace: item already has been sold");
        require(_tracking[itemId].cancelled == false, "Marketplace: owner cancelled post");
        require(msg.value >= _tracking[itemId].price, "Marketplace: incorrect asking price");

        _gate = locked;

        address seller = _tracking[itemId].seller;

        (bool success, ) = payable(seller).call{value: msg.value}("");
        require(success, "Marketplace: ether transfer failed");

        address nftContract = _tracking[itemId].nftContract;
        uint256 tokenId = _tracking[itemId].tokenId;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        _tracking[itemId].owner = msg.sender;

        _tracking[itemId].sold = true;

        emit Sale(
            itemId,
            nftContract,
            tokenId,
            seller,
            msg.sender,
            msg.value
        );

        _gate = unlocked;
    }
}