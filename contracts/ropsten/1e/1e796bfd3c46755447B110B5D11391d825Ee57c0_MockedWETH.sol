// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/TransferHelper.sol";


contract MockedWETH is ERC20 {

    constructor() ERC20("MockedWETH", "MWETH") {
        _mint(address(this), 500000 * 10 ** decimals());
    }

    function deposit() external payable {
        transfer(msg.sender, msg.value);
    }

    function withdraw(uint value) external {
        TransferHelper.safeTransferCurrency(msg.sender, value);
    }
}