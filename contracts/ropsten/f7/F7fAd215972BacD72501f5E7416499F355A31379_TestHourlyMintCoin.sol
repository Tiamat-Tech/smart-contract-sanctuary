//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;

import "./MintHourlyERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TestHourlyMintCoin is ERC20, Ownable, MintHourlyERC20 {

    constructor() MintHourlyERC20(_msgSender(), 1000 * 10 ** uint(decimals()), 1, "TestHourlyMintCoin", "HOURCOIN") {
        return;
    }

    function checkAndMint() public onlyOwner {
        if(readyToMint()) {
            mint();
        }
    }

}