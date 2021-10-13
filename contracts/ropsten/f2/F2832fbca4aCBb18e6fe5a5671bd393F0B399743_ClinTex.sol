//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ClinTex is ERC20, Ownable {
    using SafeMath for uint256;
    uint256 public unfreezeDate = 0;
    
    mapping(address => uint256) private _freezeTokens;
    constructor(string memory name, string memory symbol) ERC20 (name, symbol){
        
    }

    //isFreeze check sender transfer for amount frozen tokens
    modifier isFreeze(address sender, uint256 amount) {
        require(isTransferFreezeTokens(sender, amount) == false, "ClinTex: could not transfer frozen tokens");
        _;
    } 

    //mint is basic mint
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    //transfer is basic transfer with isFreeze modifer
    function transfer(address recipient, uint256 amount) public virtual override isFreeze(_msgSender(), amount) returns (bool) {
        return super.transfer(recipient, amount);
    }

    //transferFrom is basic transferFrom with isFreeze modifer
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override isFreeze(sender, amount) returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    //setUnfreezeDate sets freeze UNIX-time 
    function setUnfreezeDate(uint256 date) public onlyOwner{
        unfreezeDate = date;
    }

    //setFreezeTokens freezes tokens on the account
    function setFreezeTokens(address account, uint256 amount) public onlyOwner returns (bool){
        require(account != address(0), "ClinTex: address must not be empty");
        require(balanceOf(account) >= amount, "ClinTex: freeze amount exceeds allowance");
        _freezeTokens[account] = amount;
        return true;
    }

    //getFreezeTokens returns the number of frozen tokens on the account
    function getFreezeTokens(address account) public view returns (uint256) {
        require(account != address(0), "ClinTex: address must not be empty");
        return _freezeTokens[account];
    }

    //isTransferFreezeTokens returns true when transferring frozen tokens
    function isTransferFreezeTokens(address account, uint256 amount) public view returns (bool) {
        if (block.timestamp > unfreezeDate){
            return false;
        }

        if (balanceOf(account) - amount <= getFreezeTokens(account)) {
            return true;
        }

        return false;
    }
}