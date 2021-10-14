// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Splitter is PaymentSplitter, AccessControl {
    constructor(address[] memory _payees, uint256[] memory _shares)
        PaymentSplitter(_payees, _shares)
    {
        for (uint8 i = 0; i < _payees.length; i++) {
            _setupRole(DEFAULT_ADMIN_ROLE, _payees[i]);
        }
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account)
        public
        virtual
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        super.release(account);
    }
}