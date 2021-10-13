//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HOKKAirdrop is Ownable {
    using SafeMath for uint256;

    IERC20 public hokkToken;

    mapping(address => uint256) public allocations;
    mapping(address => bool) public claimedAddresses;

    constructor(address hokkAddress) {
        hokkToken = IERC20(hokkAddress);
    }

    function setAllocations(
        address[] memory addresses,
        uint256[] memory amounts
    ) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; ++i) {
            address _address = addresses[i];
            uint256 _amount = amounts[i] * (10**13);

            allocations[_address] = _amount;
            claimedAddresses[_address] = false;
        }
    }

    function claim() public {
        address _address = msg.sender;
        uint256 amount = allocations[_address];

        require(amount > 0, "Address not listed.");
        require(!claimedAddresses[_address], "Already claimed.");

        uint256 balance = hokkToken.balanceOf(address(this));
        require(balance >= amount, "Not enough balance.");

        hokkToken.transfer(_address, amount);
        claimedAddresses[_address] = true;
    }
}