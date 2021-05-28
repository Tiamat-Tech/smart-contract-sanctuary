// SPDX-License-Identifier: MIT

pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

struct Tokens {
    uint256 coinType;
    IERC20 tokenAddress;
    string tokenName;
}

contract SubGameSwap is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event ReceiveSwap(address from, uint256 fromCoinType, string to, uint256 amount);
    event Send(address to, uint256 toCoinType, uint256 amount, string swapHash);

    mapping(uint256 => Tokens) tokens;

    constructor(IERC20 addr, uint256 coinType, string memory tokenName) {
        tokens[coinType].coinType = coinType;
        tokens[coinType].tokenAddress = addr;
        tokens[coinType].tokenName = tokenName;
    }

    function receiveSwap(string calldata to, uint256 fromCoinType, uint256 amount) external {
        require(amount >= 10, "amount must greater or equal to 10");
        require(tokens[fromCoinType].coinType == fromCoinType, "token not allowed");
        tokens[fromCoinType].tokenAddress.safeTransferFrom(msg.sender, address(this), amount);
        emit ReceiveSwap(msg.sender, fromCoinType, to, amount);
    }

    function send(address to, uint256 toCoinType, uint256 amount, string calldata swapHash) external onlyOwner {
        require(amount >= 10, "amount must greater or equal to 10");
        require(tokens[toCoinType].coinType == toCoinType, "token not allowed");
        tokens[toCoinType].tokenAddress.safeTransfer(to, amount);
        emit Send(to, toCoinType, amount, swapHash);
    }

    function tokenInfo(uint256 coinType) public view returns (Tokens memory) {
        require(tokens[coinType].coinType == coinType, "token not allowed");
        return tokens[coinType];
    }

    function newToken(IERC20 addr, uint256 newCoinType, string calldata tokenName) external onlyOwner {
        require(tokens[newCoinType].coinType != newCoinType, "token existed");
        tokens[newCoinType].coinType = newCoinType;
        tokens[newCoinType].tokenAddress = addr;
        tokens[newCoinType].tokenName = tokenName;
    }

    function delToken(uint256 coinType) external onlyOwner {
        require(tokens[coinType].coinType == coinType, "token not allowed");
        uint256 newCoinType = 0;
        tokens[coinType].coinType = newCoinType;
    }
}