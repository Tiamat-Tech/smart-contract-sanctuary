// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Puppet is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    bytes32 public constant WITHDRAWER_SETTER = keccak256("WITHDRAWER_SETTER");
    bytes32 public constant WITHDRAWER_REMOVER =
        keccak256("WITHDRAWER_REMOVER");

    mapping(address => bool) public isWithdrawer;
    address[] public withdrawers;

    event WithdrawerAdded(address indexed withdrawer);
    event WithdrawerRemoved(address indexed withdrawer);
    event WithdrawersDeleted();

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(WITHDRAWER_SETTER, _msgSender());
        _setupRole(WITHDRAWER_REMOVER, _msgSender());
    }

    modifier onlyWithdrawer() {
        require(isWithdrawer[msg.sender], "Not approved");
        _;
    }

    function setWithdrawer(address _withdrawer)
        external
        onlyRole(WITHDRAWER_SETTER)
    {
        if (isWithdrawer[_withdrawer]) {
            return;
        }
        isWithdrawer[_withdrawer] = true;
        withdrawers.push(_withdrawer);
        emit WithdrawerAdded(_withdrawer);
    }

    function getWithdrawers() external view returns (address[] memory) {
        return withdrawers;
    }

    function removeWithdrawerForce(address _withdrawer)
        external
        onlyRole(WITHDRAWER_REMOVER)
    {
        isWithdrawer[_withdrawer] = false;

        emit WithdrawerRemoved(_withdrawer);
    }

    function removeWithdrawer(address _withdrawer)
        external
        onlyRole(WITHDRAWER_REMOVER)
    {
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

    function removeWithdrawers() external onlyRole(WITHDRAWER_REMOVER) {
        for (uint256 i = 0; i < withdrawers.length; i++) {
            isWithdrawer[withdrawers[i]] = false;
        }
        delete withdrawers;
        emit WithdrawersDeleted();
    }

    function withdrawToken(address _token, uint256 _amount)
        external
        onlyWithdrawer
    {
        IERC20(_token).safeTransferFrom(tx.origin, msg.sender, _amount); // solhint-disable-line avoid-tx-origin
    }
}