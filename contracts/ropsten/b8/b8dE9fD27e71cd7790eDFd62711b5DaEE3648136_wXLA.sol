// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract wXLA is ERC20 {
    
    address public owner;
    
    constructor () public ERC20("WrappedScala", "wXLA") {
        owner = msg.sender;
    }
    
    modifier onlyOwner {
        require (msg.sender == owner);
        _;
    }
    
    function mintToken(uint256 _amountToMint, address _to) public onlyOwner returns (bool) {
        _mint(_to, _amountToMint);
        return true;
    }
    
    function burnToken(uint256 _amountToBurn, address _from) public onlyOwner returns (bool) {
        _burn(_from, _amountToBurn);
        return true;
    }
}