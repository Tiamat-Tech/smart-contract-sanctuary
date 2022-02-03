pragma solidity ^0.8.4;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// learn more: https://docs.openzeppelin.com/contracts/3.x/erc20

contract YourToken is ERC20 {
    constructor() public ERC20("7BC PLN", "7BC") {}

    mapping(address => uint256) public lockTime;

    function mint5000(address accountAddress) public {
        require(
            block.timestamp > lockTime[msg.sender],
            "lock time has not expired. Please try again later"
        );

        _mint(accountAddress, 5000 * 10**18);
        // block.number
        lockTime[msg.sender] = block.timestamp + 5 minutes;
    }

    function getLockTimeout(address askingAddres)
        public
        view
        returns (uint256)
    {
        return lockTime[askingAddres];
    }
}