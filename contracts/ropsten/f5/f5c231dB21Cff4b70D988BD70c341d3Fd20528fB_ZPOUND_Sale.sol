//"SPDX-License-Identifier: MIT"
pragma  solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
contract ZPOUND is ERC20,ERC20Detailed,Ownable {
    constructor(string memory name, string  memory symbol, uint8 decimals,uint256 initialAmount) public
    ERC20Detailed (name,symbol,decimals) 
    {
        _mint(msg.sender, initialAmount * (uint256(10) **  decimals));
    }
    /**
     * @dev Allow to recover any ERC20 sent into the contract for error , Remember that only owner can call so be careful when use on contracts generated from other contracts.
     * @param tokenAddress The token contract address
     * @param tokenAmount Number of tokens to be sent
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}