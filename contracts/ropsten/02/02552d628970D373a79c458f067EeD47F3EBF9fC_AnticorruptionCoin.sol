//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "hardhat/console.sol";

/*
* https://docs.openzeppelin.com/contracts/4.x/erc20
*/
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* https://docs.openzeppelin.com/contracts/4.x/access-control#ownership-and-ownable
*/
import "@openzeppelin/contracts/access/Ownable.sol";

contract AnticorruptionCoin is Ownable, ERC20 {

    constructor() ERC20("AnticorruptionCoin", "ACC") {
        uint initialSupply = 100000000;
        _mint(msg.sender, initialSupply);
        lastMintingTimestamp = block.timestamp;
        if (block.chainid == 1) {
            // MainNet
            newTokensTime = 30 days;
        } else {
            // test nets
            newTokensTime = 10 minutes;
        }
        console.log("Deploying contracts with initial supply of", initialSupply, "tokens");
    }

    // see: https://docs.openzeppelin.com/contracts/4.x/erc20#a-note-on-decimals
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /*
    * time period between minting new tokens
    */
    uint public newTokensTime;

    uint public lastMintingTimestamp;

    uint public newTokensBatchSize = 500000;

    function mint() public onlyOwner {
        require(block.timestamp - lastMintingTimestamp > newTokensTime, "Need to wait");
        _mint(msg.sender, newTokensBatchSize);
        lastMintingTimestamp = block.timestamp;
        console.log("New tokens minted");
    }

}