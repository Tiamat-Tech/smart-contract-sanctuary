/// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interface/IRegistry.sol";


contract MockTribe is ERC20 {

    constructor(address registry, string memory name, string memory symbol) ERC20(name, symbol) {
        IRegistry(registry).setTribeTokenAddress(address(this));
    }
    
    /// mints NFT to `to`
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

}