// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";

contract Token is IERC20 {
    string public name;
    string public symbol;

    uint256 public decimals;
    uint256 public totalSupply;

    address treasury;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _decimals,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;

        decimals = _decimals;
        totalSupply = _initialSupply;

        treasury = msg.sender;

        balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    /**********  Utility Functions  **********/
    function transferTreasury(address _new) public onlyTreasury {
        treasury = _new;
    }

    /**********  ERC20 Functions  **********/
    function balanceOf(address _owner) external view override returns (uint256 balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) external override returns (bool success) {
        require(_to != address(0));
        require(balances[msg.sender] >= _value);

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external override onlyTreasury returns (bool success) {
        require(_to != address(0));
        require(balances[_from] >= _value);

        balances[_from] -= _value;
        balances[_to] += _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external override returns (bool success) {
        allowances[msg.sender][_spender] += _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    /**********  ERC20 Extensions  **********/
    function mint(address _to, uint256 _amount) public onlyTreasury {
        totalSupply += _amount;
        balances[_to] += _amount;

        emit Transfer(address(0), _to, _amount);
    }

    function burn(uint256 _amount) public {
        require(balances[msg.sender] >= _amount);

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;

        emit Transfer(msg.sender, address(0), _amount);
    }

    function burnFrom(address _from, uint256 _amount) public onlyTreasury {
        require(balances[_from] >= _amount);

        totalSupply -= _amount;
        balances[_from] -= _amount;

        emit Transfer(_from, address(0), _amount);
    }

    /**********  Modifiers  **********/
    modifier onlyTreasury() {
        require(msg.sender == treasury);
        _;
    }
}