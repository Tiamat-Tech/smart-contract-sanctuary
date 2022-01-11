// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "./LibraryToken.sol";

contract ETHWrapper {

    LibraryToken private LIBToken;

    event LogETHWrapped(address sender, uint amount);
    event LogETHUnwrapped(address sender, uint amount);

    constructor(address LIBTokenAddress) public {
        LIBToken = LibraryToken(LIBTokenAddress);
    }

    function wrap(uint value) public payable {
        require(value > 0, "We need to wrap at least 1 wei");
        LIBToken.mint(msg.sender, value);
        emit LogETHWrapped(msg.sender, value);
    }

    function unwrap(uint value) public {
        require(value > 0, "We need to unwrap st least 1 wei");
        LIBToken.transferFrom(msg.sender, address(this), value);
        LIBToken.burn(value);
        msg.sender.transfer(value);
        emit LogETHUnwrapped(msg.sender, value);
    }

    receive() external payable {
        wrap(msg.value);
    }

    fallback() external payable {
        wrap(msg.value);
    }
}