//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Gm {

    event EthereumSaysGMBack();

    function gm() external {
        emit EthereumSaysGMBack();
    }

}