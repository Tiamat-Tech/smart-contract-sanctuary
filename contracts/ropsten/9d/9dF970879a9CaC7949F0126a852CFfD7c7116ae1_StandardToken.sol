// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./IERC20.sol";
import "../Treasury.sol";
import "../lib/SafeMath.sol";

/**
    @title Token
    @notice Variable supply ERC20 token for tokens and shares.
*/
contract StandardToken is IERC20 {
    using SafeMath for uint256;

    event Mint(address _to, uint256 _amount);
    event Burn(address _to, uint256 _amount);

    /** @notice The address of the treasury. Initially assigned to whoever deploys the contract, but automatically transfered. */
    address public minter;
    Treasury public treasury;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialAmount
    ) public IERC20(_name, _symbol, 18, _initialAmount) {
        minter = msg.sender; // Temporary.

        totalSupply = _initialAmount;
        balances[msg.sender] = _initialAmount;
    }

    function setTreasury(address _treasury) public {
        require(msg.sender == minter, "Minter only");
        minter = _treasury;
        treasury = Treasury(_treasury);
    }

    /**
        @notice Mints new shares
        @param _to Where to send the new shares
        @param _amount The amount of shares to mint
    */
    function mint(address _to, uint256 _amount) public treasuryOnly {
        totalSupply += _amount;
        balances[_to] += _amount;

        emit Mint(_to, _amount);
    }

    /**
        @notice Burns shares.
        @param _amount The amount of shares to burn.
    */
    function burn(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "Insufficent balance.");
        require(_amount <= totalSupply, "Insufficent supply.");

        totalSupply -= _amount;
        balances[msg.sender] -= _amount;

        emit Burn(msg.sender, _amount);
    }

    /**
        @notice Burns shares from a specified address. Only callable by treasury.
        @param _from Address to burn from.
        @param _amount The amount to burn.
    */
    function burnFrom(address _from, uint256 _amount) public treasuryOnly {
        require(_from != address(0), "Null address");
        require(balances[_from] >= _amount, "Insufficient balance.");

        totalSupply -= _amount;
        balances[_from] -= _amount;

        emit Burn(_from, _amount);
    }

    /**
        @notice Function can only be called by treasury.
    */
    modifier treasuryOnly() {
        require(msg.sender == minter, "Minter only.");
        _;
    }
}