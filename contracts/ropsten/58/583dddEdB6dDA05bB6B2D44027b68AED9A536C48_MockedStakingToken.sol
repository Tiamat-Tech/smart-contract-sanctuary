// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MockedStakingToken is ERC20("MockedStakingToken", "MRT") {
    function mint(address account, uint256 amount) public returns (bool success) {
        _mint(account, amount);
        return true;
    }
}