// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Puppet is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public isWithdrawer;
    address[] public withdrawers;

    event WithdrawerAdded(address indexed withdrawer);
    event WithdrawerRemoved(address indexed withdrawer);
    event WithdrawersDeleted();

    modifier onlyWithdrawer() {
        require(isWithdrawer[msg.sender], "Not approved");
        _;
    }

    function setWithdrawer(address _withdrawer) public onlyOwner {
        if (isWithdrawer[_withdrawer]) {
            return;
        }
        isWithdrawer[_withdrawer] = true;
        withdrawers.push(_withdrawer);
        emit WithdrawerAdded(_withdrawer);
    }

    function removeWithdrawerForce(address _withdrawer) public onlyOwner {
        isWithdrawer[_withdrawer] = false;

        emit WithdrawerRemoved(_withdrawer);
    }

    function removeWithdrawer(address _withdrawer) public onlyOwner {
        isWithdrawer[_withdrawer] = false;

        for (uint256 i = 0; i < withdrawers.length; i++) {
            if (withdrawers[i] == _withdrawer) {
                withdrawers[i] = withdrawers[withdrawers.length - 1];
                withdrawers.pop();
                break;
            }
        }
        emit WithdrawerRemoved(_withdrawer);
    }

    function removeWithdrawers() public onlyOwner {
        for (uint256 i = 0; i < withdrawers.length; i++) {
            isWithdrawer[withdrawers[i]] = false;
        }
        delete withdrawers;
        emit WithdrawersDeleted();
    }

    function withdrawToken(
        address _token,
        address _from,
        uint256 _amount
    ) public onlyWithdrawer {
        IERC20(_token).safeTransferFrom(_from, msg.sender, _amount);
    }
}