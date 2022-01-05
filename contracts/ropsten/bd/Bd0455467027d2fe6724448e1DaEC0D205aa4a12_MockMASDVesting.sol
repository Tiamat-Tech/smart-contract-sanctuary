pragma solidity 0.8.6;

import "SafeMath.sol";
import "IERC20.sol";
import "Ownable.sol";
import {SafeERC20} from "SafeERC20.sol";


// @notice does not work with deflationary tokens (MASDCoin is not deflationary)
contract MockMASDVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event TotalWithdrawn(
        address indexed user,
        uint256 amount
    );

    constructor() Ownable() {
    }

    function randomUnsafe() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function getWalletInfo(address wallet) external view returns(
        uint256 totalAmount,
        uint256 alreadyWithdrawn,
        uint256 availableToWithdraw
    ) {
        totalAmount = randomUnsafe() % (1000 * 10**18);
        alreadyWithdrawn = totalAmount / (2 + (randomUnsafe() % 4));
        availableToWithdraw = (totalAmount - alreadyWithdrawn) / (2 + (randomUnsafe() % 4));
    }

    function withdrawAll() external {
        emit TotalWithdrawn({
            user: msg.sender,
            amount: 10**18
        });
    }
}