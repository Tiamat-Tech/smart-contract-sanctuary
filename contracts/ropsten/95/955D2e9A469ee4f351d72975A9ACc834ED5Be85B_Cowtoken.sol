pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/ICowToken.sol";

/** @author Centric Technologies PTY LTD
    @title A unique cattle identification platform */
contract Cowtoken is IERC20, ERC20, ICowToken, Ownable{

    constructor (uint256 total_supply) 
    ERC20("Cowtoken", "CWT"){
        _mint(owner(), total_supply*100000000000);
    }

    function mint(address to, uint256 amount) onlyOwner override public  {
        _mint(to, amount);
    }

 
}