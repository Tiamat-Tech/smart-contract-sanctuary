// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./token/ITenSetToken.sol";


contract Swapper is Ownable {

    using Address for address payable;
    using SafeMath for uint256;

    address public token;
    address payable public feeWallet;
    uint256 public swapFee;
    uint256 public minAmount;

    event SwapStarted(address indexed tokenAddr, address indexed fromAddr, uint256 amount);
    event SwapFinalized(address indexed tokenAddr, address indexed toAddress, uint256 amount);

    constructor(address payable _feeWallet) {
        feeWallet = _feeWallet;
    }

    function setSwapFee(uint256 fee) onlyOwner external {
        swapFee = fee;
    }

    function setMinAmount(uint256 newMinAmount) onlyOwner external {
        minAmount = newMinAmount;
    }

    function setFeeWallet(address payable newWallet) onlyOwner external {
        feeWallet = newWallet;
    }

    function setToken(address newToken) onlyOwner external returns (bool) {
        token = newToken;
        return true;
    }

    function finalizeSwap(address toAddress, uint256 amount) onlyOwner external returns (bool) {
        IERC20(token).transfer(toAddress, amount);
        emit SwapFinalized(token, toAddress, amount);
        return true;
    }

    function startSwap(uint256 amount) payable external returns (bool) {
        require(msg.value >= swapFee, "wrong swap fee");
        require(amount >= minAmount, "amount is too small");
        uint256 netAmount = ITenSetToken(token).tokenFromReflection(_msgSender(), amount);
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        feeWallet.transfer(swapFee);
        emit SwapStarted(token, msg.sender, amount);
        return true;
    }
}