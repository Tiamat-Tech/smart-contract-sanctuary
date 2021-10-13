//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ClinTex is ERC20, Ownable {
    using SafeMath for uint256;
    uint256 public unfreezeDate;
    
    mapping(address => uint256) private _freezeTokens;
    constructor(string memory name, string memory symbol) ERC20 (name, symbol){
        
    }

    modifier isFreeze(address sender, uint256 amount) {
        assert(!isTransferFreezeTokens(sender, amount));
        _;
    } 

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function transfer(address recipient, uint256 amount) public override isFreeze(_msgSender(), amount) returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override isFreeze(sender, amount) returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function setUnfreezeDate(uint256 date) public onlyOwner{
        unfreezeDate = date;
    }

    function setFreezeTokens(address account, uint256 amount) public onlyOwner returns (bool){
        require(account != address(0), "ClinTex: address must not be empty");
        require(balanceOf(account) >= amount, "ClinTex: freeze amount exceeds allowance");
        _freezeTokens[account] = amount;
        return true;
    }

    function getFreezeTokens(address account) public view returns (uint256) {
        require(account != address(0), "ClinTex: address must not be empty");
        return _freezeTokens[account];
    }

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