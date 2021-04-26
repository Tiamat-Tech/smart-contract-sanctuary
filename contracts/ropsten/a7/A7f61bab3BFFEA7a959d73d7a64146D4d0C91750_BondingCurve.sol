// contracts/BondingCurve.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BondingCurve is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    event Claimed(address indexed account, uint userShare, uint hegicAmount);
    event Received(address indexed account, uint amount);

    uint public constant START = 1599678000;
    uint public constant END = START + 3 days;
    uint public constant TOTAL_DISTRIBUTE_AMOUNT = 90_360_300e18;
    uint public constant MINIMAL_PROVIDE_AMOUNT = 700 ether;
    uint public totalProvided = 0;
    mapping(address => uint) public provided;
    IERC20 public immutable RUG;

    constructor(IERC20 rug) public {
        RUG = rug;
    }

    receive() external payable {
        require(START <= block.timestamp, "The offering has not started yet");
        require(block.timestamp <= END, "The offering has already ended");
        totalProvided += msg.value;
        provided[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    function claim() external {
        require(block.timestamp > END);
        require(provided[msg.sender] > 0);

        uint userShare = provided[msg.sender];
        provided[msg.sender] = 0;

        if(totalProvided >= MINIMAL_PROVIDE_AMOUNT) {
            uint rugAmount = TOTAL_DISTRIBUTE_AMOUNT
                .mul(userShare)
                .div(totalProvided);
            RUG.safeTransfer(msg.sender, rugAmount);
            emit Claimed(msg.sender, userShare, rugAmount);
        } else {
            msg.sender.transfer(userShare);
            emit Claimed(msg.sender, userShare, 0);
        }
    }

    function withdrawProvidedETH() external onlyOwner {
        require(END < block.timestamp, "The offering must be completed");
        require(
            totalProvided >= MINIMAL_PROVIDE_AMOUNT,
            "The required amount has not been provided!"
        );
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawRUG() external onlyOwner {
        require(END < block.timestamp, "The offering must be completed");
        require(
            totalProvided < MINIMAL_PROVIDE_AMOUNT,
            "The required amount has been provided!"
        );
        RUG.safeTransfer(owner(), RUG.balanceOf(address(this)));
    }

    function withdrawUnclaimedRUG() external onlyOwner {
        require(END + 30 days < block.timestamp, "Withdrawal unavailable yet");
        RUG.safeTransfer(owner(), RUG.balanceOf(address(this)));
    }
}