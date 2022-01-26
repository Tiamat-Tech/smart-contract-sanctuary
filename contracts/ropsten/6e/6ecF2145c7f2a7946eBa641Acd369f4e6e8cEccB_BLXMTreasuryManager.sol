// SPDX-License-Identifier: GPL-3.0 License

pragma solidity ^0.8.0;

import "./interfaces/IBLXMTreasuryManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/ITreasury.sol";

import "./libraries/BLXMLibrary.sol";

contract BLXMTreasuryManager is Ownable, IBLXMTreasuryManager {

    // token A(B) => token B(A) => treasury
    mapping(address => mapping(address => address)) public override getTreasury;
    address[] public override allTreasury;

    function putTreasury(address tokenA, address tokenB, address treasury) external override onlyOwner {
        require(treasury != address(0), 'TREASURY_NOT_FOUND');
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');

        getTreasury[token0][token1] = treasury;
        getTreasury[token1][token0] = treasury; // populate mapping in the reverse direction

        allTreasury.push(treasury);
        emit TreasuryPut(token0, token1, treasury, allTreasury.length);
    }

    function allTreasuryLength() external view override returns (uint) {
        return allTreasury.length;
    }
}