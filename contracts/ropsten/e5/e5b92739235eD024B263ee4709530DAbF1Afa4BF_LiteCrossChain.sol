// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./helpers/OwnableUpgradeable.sol";

contract LiteCrossChain is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public usdtToken;

    mapping(address => uint) public usersBalance;

    event Swapped(address indexed user, uint amount);
    event Withdrawn(address indexed user, uint amount);

    function initialize(
        address _usdtToken
    ) public initializer {
        OwnableUpgradeable.initialize();
        usdtToken = IERC20Upgradeable(_usdtToken);
    }

    function swap(uint _amount) external {
        require(_amount > 0, "LiteCrossChain: cannot swap 0");

        uint balanceBefore = usdtToken.balanceOf(address(this));
        usdtToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint balanceAfter = usdtToken.balanceOf(address(this));
        require(balanceBefore + _amount == balanceAfter, "LiteCrossChain: insufficient contract balance");

        usersBalance[msg.sender] += _amount;
        emit Swapped(msg.sender, _amount);
    }

    function withdraw(address _receiver, uint _amount) external onlyOwner {
        require(_receiver != address(0), "LiteCrossChain: receiver is not valid");
        require(_amount > 0, "LiteCrossChain: cannot withdraw 0");
        require(getBalance(_receiver) >= _amount, "LiteCrossChain: insufficient receiver balance");

        usersBalance[_receiver] -= _amount;

        usdtToken.safeTransfer(_receiver, _amount);
        emit Withdrawn(_receiver, _amount);
    }

    function withdrawAllByOwner() external onlyOwner {
        uint balance = usdtToken.balanceOf(address(this));
        withdrawByOwner(balance);
    }

    function withdrawByOwner(uint _amount) public onlyOwner {
        require(_amount > 0, "LiteCrossChain: cannot withdraw 0");

        usdtToken.safeTransfer(owner(), _amount);
        emit Withdrawn(owner(), _amount);
    }

    function getBalance(address _address) public view returns (uint) {
        return usersBalance[_address];
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}