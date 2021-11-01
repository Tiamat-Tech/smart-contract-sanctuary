// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../libs/Math.sol";
import "../libs/SafeMath.sol";
import "../libs/IERC20.sol";
import "../libs/SafeERC20.sol";

contract VirtualBalanceWrapper {
    using SafeMath for uint256;

    address public operator;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address _operator) public {
        operator = _operator;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stakeFor(address _for, uint256 _amount) public returns (bool) {
        require(msg.sender == operator, "!authorized");
        require(_amount > 0, "VirtualBalanceWrapper : Cannot stake 0");

        _totalSupply = _totalSupply.add(_amount);
        _balances[_for] = _balances[_for].add(_amount);

        return true;
    }

    function withdrawFor(address _for, uint256 amount) public returns (bool) {
        require(msg.sender == operator, "!authorized");
        require(amount > 0, "RewardPool : Cannot withdraw 0");

        _totalSupply = _totalSupply.sub(amount);
        _balances[_for] = _balances[_for].sub(amount);

        return true;
    }
}

contract VirtualBalanceWrapperFactory {
    function CreateVirtualBalanceWrapper(address op) public returns (address) {
        VirtualBalanceWrapper virtualBalanceWrapper = new VirtualBalanceWrapper(
            op
        );

        return address(virtualBalanceWrapper);
    }
}