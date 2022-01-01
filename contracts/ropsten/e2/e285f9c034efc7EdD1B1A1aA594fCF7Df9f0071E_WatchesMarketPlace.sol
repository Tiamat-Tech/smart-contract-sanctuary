// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./WatchesTokenWhitelist.sol";
import "./WatchesToken.sol";

contract WatchesMarketPlace is WatchesToken, WatchesTokenWhitelist {
    uint256 private _whitelistedPrice = 0.075 * 1e18;
    uint256 private _standardPrice = 0.15 * 1e18;
    uint256 private _limitPerWallet = 4;
    uint256 private _limitPerTsc = 2;

    enum ItemPrice {
        Standard,
        whiteListed,
        LimitPerWallet,
        LimitPerTsc
    } // 0, 1, 3, 4

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        address _owner
    ) WatchesToken(_name, _symbol) {
        _transferOwnership(_owner); // set owner of contract
        _setBaseURI(_baseURI);
    }

    modifier requirePayable() {
        require(msg.value > 0, "You need to send some ether");
        _;
    }

    function _transferToOwner() internal returns (bool success) {
        payable(owner()).transfer(address(this).balance);
        success = true;
    }

    function whitelistPrice() public view returns (uint256) {
        return _whitelistedPrice;
    }

    function standardPrice() public view returns (uint256) {
        return _standardPrice;
    }

    function limitPerWallet() public view returns (uint256) {
        return _standardPrice;
    }

    function limitPerTsc() public view returns (uint256) {
        return _standardPrice;
    }

    function mintTo(address _to, uint256 _amount)
        public
        payable
        requirePayable
        returns (bool success)
    {
        require(
            _amount <= _limitPerTsc,
            "That's more than max tokens per transaction"
        );
        require(
            balanceOf(msg.sender) + _amount <= _limitPerWallet,
            "That's more than max tokens per wallet, sale not allowed"
        );

        if (isWhitelisted(msg.sender)) {
            require(
                msg.value >= _whitelistedPrice * _amount,
                "Not enough ETH for transaction"
            );
            require(_transferToOwner(), "Transfer ETH to owner is failed");
            for (uint256 i = 0; i < _amount; i++) {
                _safeMintToken(_to);
            }
            success = true;
        } else {
            require(
                msg.value >= _standardPrice * _amount,
                "Not enough ETH for transaction"
            );
            require(_transferToOwner(), "Transfer ETH to owner is failed");
            for (uint256 i = 0; i < _amount; i++) {
                _safeMintToken(_to);
            }
            success = true;
        }
    }

    function setConfig(ItemPrice _type, uint256 _amount)
        public
        onlyOwner
        returns (bool success)
    {
        if (_type == ItemPrice.Standard) {
            _standardPrice = _amount;
            success = true;
        } else if (_type == ItemPrice.whiteListed) {
            _whitelistedPrice = _amount;
            success = true;
        } else if (_type == ItemPrice.LimitPerWallet) {
            _limitPerWallet = _amount;
            success = true;
        } else if (_type == ItemPrice.LimitPerTsc) {
            _limitPerTsc = _amount;
            success = true;
        }
    }

    function withdraw() public onlyOwner {
        _transferToOwner();
    }
}