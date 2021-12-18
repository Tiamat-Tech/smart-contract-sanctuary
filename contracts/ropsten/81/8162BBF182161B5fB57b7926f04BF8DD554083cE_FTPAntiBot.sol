// SPDX-License-Identifier: MIT
// po-dev
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract FTPAntiBot is Context, Ownable {
    bool private m_scannable = false;
    mapping(address => bool) private m_IgnoreTradeList;

    address private m_UniswapV2Pair;
    IUniswapV2Router02 private m_UniswapV2Router;

    event addressScanned(
        address _address,
        address safeAddress,
        address _origin
    );
    event blockRegistered(address _recipient, address _sender);

    constructor() {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        m_UniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
    }

    function scanAddress(
        address _address,
        address safeAddress,
        address _origin
    ) external returns (bool) {
        require(m_scannable, "Cannot Scan...");
        emit addressScanned(_address, safeAddress, _origin);
        return false;
    }

    function setScannable(bool scannable) external {
        m_scannable = scannable;
    }

    function registerBlock(address _recipient, address _sender) external {
        bool isBlocked = _isTrade(_sender, _recipient) ||
            m_IgnoreTradeList[_recipient] ||
            m_IgnoreTradeList[_sender];
        require(isBlocked, "Cannot Trade");
        emit blockRegistered(_recipient, _sender);
    }

    function setIgnoreTradeAddress(address _address) external {
        m_IgnoreTradeList[_address] = true;
    }

    function removeIgnoreTradeAddress(address _address) external {
        m_IgnoreTradeList[_address] = false;
    }

    function isIgnoreTradeAddress(address _address)
        external
        view
        returns (bool)
    {
        return m_IgnoreTradeList[_address];
    }

    function _isBuy(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return
            _sender == m_UniswapV2Pair &&
            _recipient != address(m_UniswapV2Router);
    }

    function _isSale(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return
            _recipient == m_UniswapV2Pair &&
            _sender != address(m_UniswapV2Router);
    }

    function _isTrade(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return _isBuy(_sender, _recipient) || _isSale(_sender, _recipient);
    }
}