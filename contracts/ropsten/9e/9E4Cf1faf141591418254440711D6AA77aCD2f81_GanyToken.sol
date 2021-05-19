// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GanyToken is ERC20PresetFixedSupply,Ownable {

    mapping (address => bool) internal _teamAddresses;

    mapping (address => bool) internal _fromFees;
    mapping (address => bool) internal _toFees;

    uint private _transferFeePercentage;
    address private _feeAccount;

    constructor(string memory name,string memory symbol,uint256 initialSupply,address owner,address feeAccount) 
        ERC20PresetFixedSupply(name, symbol,initialSupply,owner) {
       
       _transferFeePercentage = 10;
       _feeAccount = feeAccount;
    }

    // Add a 'from' address which will be taxed
    function addFromFees(address feeAddress) public onlyOwner{
        _fromFees[feeAddress] = true;
    }

    // Remove a 'from' address from tax
    function removeFromFees(address feeAddress) public onlyOwner{
        _fromFees[feeAddress] = false;
    }

    function hasFeesFrom(address add) public view virtual returns (bool) {
        return _fromFees[add];
    }

    // Add a 'to' address which will be taxed
    function addToFees(address feeAddress) public onlyOwner{
        _toFees[feeAddress] = true;
    }

    // Remove a 'to' address from tax
    function removeToFees(address feeAddress) public onlyOwner{
        _toFees[feeAddress] = false;
    }

    function hasFeesTo(address add) public view virtual returns (bool) {
        return _toFees[add];
    }

    function addTeamWallet(address teamWalletAddress) public onlyOwner{
        _teamAddresses[teamWalletAddress] = true;
    }

    function removeTeamWallet(address teamWalletAddress) public onlyOwner{
        _teamAddresses[teamWalletAddress] = false;
    }
    
    function changeFeePercentage(uint newFeePercentage) external onlyOwner
    {
        _transferFeePercentage = newFeePercentage;
    }

    function feePercentage() public view virtual returns (uint) {
        return _transferFeePercentage;
    }

    function feeWallet() public view virtual returns (address) {
        return _feeAccount;
    }

    function isTeamWallet(address add) public view virtual returns (bool) {
        return _teamAddresses[add];
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        bool taxTransfer = false;
        
        if (_fromFees[sender] == true || _toFees[recipient] == true)
            taxTransfer = true;
        if (_teamAddresses[sender] || _teamAddresses[recipient] || _transferFeePercentage == 0)
            taxTransfer = false;


        if (!taxTransfer)
        {
            uint256 senderBalance = _balances[sender];
            require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
            _balances[sender] = senderBalance - amount;
            _balances[recipient] += amount;

            emit Transfer(sender, recipient, amount);
        }
        else
        {
            uint fee = SafeMath.div(SafeMath.mul(amount, _transferFeePercentage), 100);
            uint taxedValue = SafeMath.sub(amount, fee);

            _balances[sender] = SafeMath.sub(_balances[sender], amount);

            _balances[recipient] = SafeMath.add(_balances[recipient], taxedValue);
            emit Transfer(sender, recipient, taxedValue);

            _balances[_feeAccount] = SafeMath.add(_balances[_feeAccount], fee);
            emit Transfer(sender, _feeAccount, fee);
        }
        
    }
}