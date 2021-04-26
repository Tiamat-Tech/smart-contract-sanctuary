// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./MyToken.sol";

contract Factory {
event TokenDeployed(address tokenAddress);

function deployNewToken(string memory _name, string memory _symbol,uint256 _initialSupply,
        uint8 decimals_)  external returns (address) {
            MyToken t = new MyToken(_name, _symbol, _initialSupply, msg.sender, decimals_);
            emit TokenDeployed(address(t));
            return address(t);
        }
}