// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableUpgradeable.sol";
import "./ERC777Upgradeable.sol";
import "./ERC777UpgradeableProxy.sol";
import "./IProxyInitialize.sol";

contract ERC777TokenFactory is OwnableUpgradeable,ERC777Upgradeable {

    address public logicImplement;

    event TokenCreated(address indexed token);

    constructor(address _logicImplement) public {
        logicImplement = _logicImplement;
    }

    function createERC777Token(string calldata name, string calldata symbol,address[] memory defaultOperators_, uint256 _totalSupply, address proxyAdmin) external onlyOwner returns (address) {
        ERC777UpgradeableProxy proxyToken = new ERC777UpgradeableProxy(logicImplement, proxyAdmin, "");

        IProxyInitialize token = IProxyInitialize(address(proxyToken));
        ERC777Upgradeable.__ERC777_init(name, symbol,defaultOperators_, _totalSupply);
        // emit TokenCreated(address(ERC777Upgradeable));
        // return address(ERC777Upgradeable);
        
    }
   
}