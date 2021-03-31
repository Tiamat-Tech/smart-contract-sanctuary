// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol"; 
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

contract Dappy {
    using SafeMath for uint256;

    address public admin;
    address public pendingAdmin;

    address public token;

    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewAdmin(address indexed newAdmin);
    event Paid(address indexed customer, uint256 cartId, string customerEmail, string customerFullName, uint256 grandTotal);

    modifier isAdmin(address _account) {
        require(admin == _account, "Restricted Access!");
        _;
    }

    constructor(address _token) public {
        admin = msg.sender;
        token = _token;
    }

    receive() external payable {
        assert(false); // We won't accept ETH
    }

    /* Update admin address */
    function setPendingAdmin(address _pendingAdmin) external isAdmin(msg.sender) {
        pendingAdmin = _pendingAdmin;
        emit NewPendingAdmin(pendingAdmin);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    /**
     * @dev Withdraw tokens from this contract (Callable by admin)
    */
    function withdraw() external isAdmin(msg.sender) {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        if (0 < tokenBalance) {
            TransferHelper.safeTransfer(token, admin, tokenBalance);
        }
    }

    function balance() external view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev PUBLIC FACING: Pay in token.
     */
    function pay(uint256 cartId, string memory customerEmail, string memory customerFullName, uint256 grandTotal) external {
        address customer = msg.sender;

        TransferHelper.safeTransferFrom(address(token), customer, address(this), grandTotal);

        emit Paid(customer, cartId, customerEmail, customerFullName, grandTotal);
    }
}