// SPDX-License-Identifier: MIT
// Example of an implementation of ERC20
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract GLDToken is ERC20 {
    uint256 private _totalSupply1;

    constructor() ERC20("GAMMA", "G4D") public {
        _totalSupply1 = 10**9;

        _mint(_msgSender(), _totalSupply1);
    }
}