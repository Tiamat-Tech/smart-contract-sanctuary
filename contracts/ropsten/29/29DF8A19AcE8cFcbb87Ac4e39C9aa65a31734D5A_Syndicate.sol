// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

enum Stages {
    WHITELIST,
    PRIVATE_SALE,
    PUBLIC_SALE
}

contract Syndicate is ERC1155, Ownable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Constants
    uint256 public constant SUBSCRIPTION_ID = 0;

    EnumerableSet.AddressSet private whitelist;
    Counters.Counter public ltId;

    uint256 private lifetimeSupply = 60;
    uint256 private subscriptionSupply = 893;
    uint256 public subscriptionMintPrice = 0.25 ether;
    uint8 public maxMintAmt = 2;

    Stages stage = Stages.WHITELIST;

    constructor(string memory _uri, uint256 _lifetimeSupply) ERC1155(_uri) {
        // Premint subscription supply
        lifetimeSupply = _lifetimeSupply;
    }

    modifier atStage(Stages _stage) {
        require(stage == _stage, "Incorrect stage");
        _;
    }

    modifier onlyWhitelist() {
        require(whitelist.contains(msg.sender), "Not on whitelist");
        _;
    }

    modifier ensureEnoughFunds(uint256 _amount) {
        require(
            msg.value >= subscriptionMintPrice * _amount,
            "Not enough funds"
        );
        _;
    }

    modifier lessThanMaxAmount(uint256 _amount) {
        require(_amount <= maxMintAmt, "Amount too large");
        _;
    }

    function initialize() external onlyOwner {
        // increment counter
        ltId.increment();

        _mint(address(this), SUBSCRIPTION_ID, subscriptionSupply, "");
    }

    function addToWhiteList(address[] memory _toAdd)
        external
        atStage(Stages.WHITELIST)
        onlyOwner
    {
        for (uint256 _i = 0; _i < _toAdd.length; _i++) {
            whitelist.add(_toAdd[_i]);
        }
    }

    function removeFromWhiteList(address[] memory _toRemove)
        external
        atStage(Stages.WHITELIST)
        onlyOwner
    {
        for (uint256 _i = 0; _i < _toRemove.length; _i++) {
            whitelist.remove(_toRemove[_i]);
        }
    }

    function inWhitelist(address _user) external view returns (bool) {
        return whitelist.contains(_user);
    }

    function setPrivateSale() external atStage(Stages.WHITELIST) onlyOwner {
        stage = Stages.PRIVATE_SALE;
    }

    function setPublicSale() external atStage(Stages.PRIVATE_SALE) onlyOwner {
        stage = Stages.PUBLIC_SALE;
    }

    function _doSubscriptionMint(uint8 _amount) internal {
        require(_amount <= balanceOf(address(this), SUBSCRIPTION_ID), "");
        _safeTransferFrom(
            address(this),
            msg.sender,
            SUBSCRIPTION_ID,
            _amount,
            ""
        );
    }

    function mintPrivate(uint8 _amount)
        external
        payable
        atStage(Stages.PRIVATE_SALE)
        onlyWhitelist
        ensureEnoughFunds(_amount)
        lessThanMaxAmount(_amount)
    {
        _doSubscriptionMint(_amount);
    }

    function mintPublic(uint8 _amount)
        external
        payable
        atStage(Stages.PUBLIC_SALE)
        ensureEnoughFunds(_amount)
        lessThanMaxAmount(_amount)
    {
        _doSubscriptionMint(_amount);
    }

    function _airdropLifetime(address _user) internal {
        uint256 _tokenId = ltId.current();
        ltId.increment();
        if (_tokenId <= lifetimeSupply) _mint(_user, _tokenId, 1, "");
    }

    function airdropLifetime(address _user) external onlyOwner {
        require(ltId.current() <= lifetimeSupply);
        _airdropLifetime(_user);
    }

    function airdropBatchLifetime(address[] memory _users) external onlyOwner {
        require(_users.length > 0, "Cannot be empty list");
        require(
            (ltId.current() - 1 + _users.length) <= lifetimeSupply,
            "not enough tokens"
        );

        for (uint8 _i = 0; _i < _users.length; _i++) {
            require(_users[_i] != address(0));
            _airdropLifetime(_users[_i]);
        }
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_id < ltId.current());
        return string(abi.encodePacked(super.uri(_id), _id, ".json"));
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}