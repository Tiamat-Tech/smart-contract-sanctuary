// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.3;


import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title Sending bulk transactions from the whitelisted wallets.
 */
contract BulkSender is Ownable {
    mapping(address => bool) whitelist;
    /**
     * Throws if called by any account other than the whitelisted address.
     */
    modifier onlyWhiteListed() {
        require(whitelist[msg.sender], "Whitelist: the caller is not whitelisted");
        _;
    }

    /**
     * Approves the address as the whitelisted address.
     */
    function approve(address addr) onlyOwner external {
        whitelist[addr] = true;
    }

    /**
     * Removes the whitelisted address from the whitelist.
     */
    function remove(address addr) onlyOwner external {
        whitelist[addr] = false;
    }

    /**
     * Returns true if the address is the whitelisted address.
     */
    function isWhiteListed(address addr) public view returns (bool) {
        return whitelist[addr];
    }

    /**
     * @dev Gets the list of addresses and the list of amounts to make bulk transactions.
     * @param addresses - address[]
     * @param amounts - uint256[]
     */
    function distribute(address[] calldata addresses, uint256[] calldata amounts) onlyWhiteListed external payable  {
        require(addresses.length > 0, "BulkSender: the length of addresses should be greater than zero");
        require(amounts.length == addresses.length, "BulkSender: the length of addresses is not equal the length of amounts");
        for (uint256 i; i < addresses.length; i++) {
            uint256 value = amounts[i];
            require(value > 0, "BulkSender: the value should be greater then zero");
            address payable _to = payable(addresses[i]);
            _to.transfer(value);
        }
        require(address(this).balance == 0, "All received funds must be transfered");
    }

    /**
     * @dev This contract shouldn't accept payments.
     */
    receive() external payable {
        revert("This contract shouldn't accept payments.");
    }
}