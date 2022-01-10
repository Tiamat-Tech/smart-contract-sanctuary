//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BlueAlder is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 public constant MAX_SUPPLY = 69696969 ether;
    uint256 public donateMinimum = 0.001 ether;

    uint256 public constant TOKENS_PER_DONATION = 100;

    constructor() ERC20("BlueAlder", "BAL") {}

    function donate() external payable {
        require(msg.value > donateMinimum, "Msg is not minimum");
        uint256 mintAmount = msg.value.div(donateMinimum);
        console.log(mintAmount);
    }

    function updateMinDonation(uint256 newAmount) external onlyOwner {
        donateMinimum = newAmount;
    }
}