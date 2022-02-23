// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/TransferHelper.sol";


contract MockedWETH is ERC20 {

    constructor() ERC20("MockedWETH", "MWETH") {
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint value) external {
        _burn(msg.sender, value);
        TransferHelper.safeTransferCurrency(msg.sender, value);
    }
}