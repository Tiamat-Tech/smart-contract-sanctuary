// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/IVault.sol";

interface IVisor {
    function delegatedTransferERC20(address token, address to, uint256 amount) external;
}

contract Extract {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IVault public hypervisor;
    address public owner;
    uint256 public bonus;
    IERC20 public bonusToken;

    constructor(
        address _hypervisor,
        address _bonusToken,
        address _owner
    ) {
        hypervisor = IVault(_hypervisor);
        bonusToken = IERC20(_bonusToken);
        owner = _owner;
    }

    function extractTokens(
        uint256 shares,
        address to,
        address from
    ) external {
        IVisor(from).delegatedTransferERC20(address(from), address(this), shares);
        uint256 withdrawShares = shares.div(2);
        IVault(hypervisor).withdraw(withdrawShares, to, address(this));
        bonusToken.safeTransfer(to, bonus.mul(shares).div(IERC20(address(hypervisor)).totalSupply()));
    }

    function setBonus(uint256 _bonus) external onlyOwner {
        bonus = _bonus;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "only owner");
        _;
    }
}