// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./token/ITenSetToken.sol";


contract Swapper is Ownable {

    using Address for address payable;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping(bytes32 => bool) public finalizedTxs;
    address public token;
    address payable public feeWallet;
    uint256 public swapFee;
    uint256 public minAmount;

    event SwapStarted(address indexed tokenAddr, address indexed fromAddr, uint256 amount, uint256 feeAmount);
    event SwapFinalized(address indexed tokenAddr, bytes32 indexed otherTxHash, address indexed toAddress, uint256 amount);

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

    function finalizeSwap(bytes32 otherTxHash, address toAddress, uint256 amount) onlyOwner external returns (bool) {
        require(!finalizedTxs[otherTxHash], "the swap has already been finalized");

        finalizedTxs[otherTxHash] = true;
        IERC20(token).safeTransfer(toAddress, amount);

        emit SwapFinalized(token, otherTxHash, toAddress, amount);
        return true;
    }

    function startSwap(uint256 amount) payable external returns (bool) {
        require(msg.value >= swapFee, "wrong swap fee");
        require(amount >= minAmount, "amount is too small");
        uint256 netAmount = ITenSetToken(token).tokenFromReflection(_msgSender(), amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        feeWallet.transfer(swapFee);
        emit SwapStarted(token, msg.sender, netAmount, msg.value);
        return true;
    }
}