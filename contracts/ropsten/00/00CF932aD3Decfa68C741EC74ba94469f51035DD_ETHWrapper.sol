// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "./WETH.sol";

contract ETHWrapper {
    WETH public WETHToken;

    event LogETHWrapped(address sender, uint amount);
    event LogETHUnwrapped(address sender, uint amount);

    constructor() {
        WETHToken = new WETH();
    }

    function wrap() public payable {
        require(msg.value > 0, "We need to wrap at least 1 wei");
        WETHToken.mint(msg.sender, msg.value);
        emit LogETHWrapped(msg.sender, msg.value);
    }

    function unwrap(uint value) public {
        require(value > 0, "We need to unwrap st least 1 wei");
        WETHToken.transferFrom(msg.sender, address(this), value);
        WETHToken.burn(value);
        msg.sender.transfer(value);
        emit LogETHUnwrapped(msg.sender, value);
    }

    receive() external payable {
        wrap();
    }
}