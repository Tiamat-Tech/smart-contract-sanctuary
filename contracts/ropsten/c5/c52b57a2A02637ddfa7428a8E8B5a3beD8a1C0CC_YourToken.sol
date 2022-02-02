// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YourToken is ERC20 {
    constructor() public ERC20("7BC PLN", "7BC") {}

    mapping(address => uint256) public lockTime;

    function mint5000(address accountAddress) public {
        require(
            block.timestamp > lockTime[msg.sender],
            "lock time has not expired. Please try again later"
        );

        _mint(accountAddress, 5000 * 10**18);

        lockTime[msg.sender] = block.timestamp + 5 seconds;
    }

    function getLockTimeout(address askingAddres)
        public
        view
        returns (uint256)
    {
        return lockTime[askingAddres];
    }
}