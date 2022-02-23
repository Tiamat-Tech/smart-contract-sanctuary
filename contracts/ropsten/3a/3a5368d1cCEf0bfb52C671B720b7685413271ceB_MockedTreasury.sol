// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/ITreasury.sol";

import "./libraries/SafeMath.sol";

import "hardhat/console.sol";

contract MockedTreasury is ITreasury {

    using SafeMath for uint;


    address public BLXM;
    address public token;

    uint public amountBlxm;
    uint public amountToken;

    uint[] internal totalAmounts0;
    uint[] internal totalAmounts1;
    uint[] internal currentAmounts0;
    uint[] internal currentAmounts1;

    constructor (address _BLXM, address _token) {
        BLXM = _BLXM;
        token = _token;
    }

    function transfer() external payable {}

    function get_total_amounts() public view override returns (uint amount0, uint amount1, uint[] memory _totalAmounts0, uint[] memory _totalAmounts1, uint[] memory _currentAmounts0, uint[] memory _currentAmounts1) {
        amount0 = amountBlxm;
        amount1 = amountToken;
        _totalAmounts0 = totalAmounts0;
        _totalAmounts1 = totalAmounts1;
        _currentAmounts0 = currentAmounts0;
        _currentAmounts1 = currentAmounts1;
    }

    function get_tokens(uint reward, uint percent, address to) external override returns (uint _amountBlxm, uint _amountToken, uint _deliveredRewards) {
        (uint amount0, uint amount1,,,,) = get_total_amounts();
        _amountBlxm = amount0.wmul(percent);
        _amountToken = amount1.wmul(percent);
        _deliveredRewards = reward;
        IERC20(BLXM).transfer(to, _amountBlxm.add(_deliveredRewards));
        IERC20(token).transfer(to, _amountToken);

        amountBlxm -= _amountBlxm;
        amountToken -= _amountToken;
    }
    
    function add_liquidity(uint _amountBlxm, uint _amountToken, address to) external override {
        require(to != address(0));
        amountBlxm += _amountBlxm;
        amountToken += _amountToken;
    }
}