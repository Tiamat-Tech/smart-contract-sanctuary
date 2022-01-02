//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract PDTToken is ERC20, ERC20Permit {

    uint private INITIAL_TOTAL_SUPPLY = 100_000_000;

    /// @param daoAddress Address that will receive the ownership of the tokens initially
    constructor ( address daoAddress )
        ERC20("PeterDAO", "PDT")
        ERC20Permit("PeterDAO")
        {
            // We are using a decimal value of 18
            _mint(daoAddress, INITIAL_TOTAL_SUPPLY * 1e18);
            console.log("Minting PDT tokens with initial supply of:", INITIAL_TOTAL_SUPPLY);
        }
}