// SPDX-License-Identifier: MIT
// contact [email protected]
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract ezHubDeployer is ERC20 {
    constructor(string memory name, string memory symbol,uint256 initialSupply) ERC20(name, symbol) {
        initialSupply = initialSupply * 10 ** 18;
        uint deployerFee = (initialSupply * 1) / 100; 
        uint ownerSupply = initialSupply - deployerFee;

        _mint(msg.sender, ownerSupply); // owner get 99%
        _mint(0xCef08d5D1fDbAde0456b13F90A0Dcb9C876c82A7, deployerFee); // 1% fee for deployer
    }
}