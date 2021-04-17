// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./ERC20/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IFactory.sol";
import "./utils/Ownable.sol";

contract MultiCall is Ownable {
    struct TokenData {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        uint256 price;
        uint256 balance;
    }

    IOracle public oracle = IOracle(0x0000000000000000000000000000000000000000);

    function getTokens(IERC20[] calldata _assets, bool[] calldata _getPrice, address _account) external view returns (TokenData[] memory data) {
        data = new TokenData[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            data[i] = getToken(_assets[i], _getPrice[i], _account);
        }
    }

    function setOracle(IOracle _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function getToken(IERC20 _asset, bool _getPrice, address _account) public view returns (TokenData memory) {
        string memory _name = _asset.name();
        string memory _symbol = _asset.symbol();
        uint8 _decimals = _asset.decimals();
        uint256 _totalSupply = _asset.totalSupply();
        uint256 _balance = _asset.balanceOf(_account);
        uint256 _price = _getPrice && address(oracle) != address(0) ? oracle.getPriceUSD(address(_asset)) : 0;
        return TokenData({
            name: _name,
            symbol: _symbol,
            decimals: _decimals,
            totalSupply: _totalSupply,
            price: _price,
            balance: _balance
        });
    }
}