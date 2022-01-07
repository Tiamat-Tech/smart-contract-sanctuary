//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReportingMemberERC20{
    event Transfer(address indexed from, address indexed to, uint256 value);

    event CommitOwnership(address admin);
    event AcceptOwnership(address admin);


    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public MAX_TOKEN_AMOUNT = 1;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address public admin;
    address public future_admin;

    constructor(address admin_, string memory name_, string memory symbol_) {
        admin = admin_;
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure  returns (uint8) {
        return 0;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function mint(address account) external {
        require(msg.sender == admin, "not admin");

        _mint(account);
    }

    function _mint(address account) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        uint256 amount = 1;

        _totalSupply += amount;
        _balances[account] += amount;

        require(_balances[account] <= MAX_TOKEN_AMOUNT, "exceed MAX_TOKEN_AMOUNT");

        emit Transfer(address(0), account, amount);
    }

    function burn(address account) external {
        if(msg.sender == account){
            _burn(msg.sender);
        }else{
            require(msg.sender == admin, "admin only");
            _burn(account);
        }
    }

    function _burn(address account) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 amount = 1;

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function commit_transfer_ownership(address addr)external {
        /***
        *@notice Transfer ownership of GaugeController to `addr`
        *@param addr Address to have ownership transferred to
        */
        require (msg.sender == admin, "dev: admin only");
        future_admin = addr;
        emit CommitOwnership(addr);
    }

    function accept_transfer_ownership()external {
        /***
        *@notice Accept a transfer of ownership
        *@return bool success
        */
        require(address(msg.sender) == future_admin, "dev: future_admin only");

        admin = future_admin;

        emit AcceptOwnership(admin);
    }

}