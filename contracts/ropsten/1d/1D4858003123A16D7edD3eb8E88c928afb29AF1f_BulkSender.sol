// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.3;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/**
 * @title Sending bulk transactions from the whitelisted wallets.
 */
contract BulkSender is Ownable {
    address public tokenAddress;

    mapping(address => bool) whitelist;
    /**
     * Throws if called by any account other than the whitelisted address.
     */
    modifier onlyWhiteListed() {
        require(whitelist[msg.sender], "Whitelist: the caller is not whitelisted");
        _;
    }

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    /**
     * Approves the address as the whitelisted address.
     */
    function approve(address addr) onlyOwner external {
        require(addr != address(0), "BulkSender: the address can not be a zero address");
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
    function distribute(address[] calldata addresses, uint256[] calldata amounts) onlyWhiteListed external {
        _checkValues(addresses, amounts);
        for (uint256 i; i < addresses.length; i++) {
            address payable _to = payable(addresses[i]);
            _to.transfer(amounts[i]);
        }
    }

    /**
     * @dev Gets the list of addresses and the list of amounts to make bulk token transfering.
     * @param addresses - address[]
     * @param amounts - uint256[]
     */
    function distributeTokens(address[] calldata addresses, uint256[] calldata amounts) onlyWhiteListed external {
        _checkValues(addresses, amounts);
        for (uint256 i; i < addresses.length; i++) {
            ERC20(tokenAddress).transfer(addresses[i], amounts[i]); 
        }
    }

    /**
     * Check if all values for addresses and amounts.
     */
    function _checkValues(address[] calldata addresses, uint256[] calldata amounts) internal {
        require(addresses.length > 0, "BulkSender: the length of addresses should be greater than zero");
        require(amounts.length == addresses.length, "BulkSender: the length of addresses is not equal the length of amounts");
        for (uint256 i; i < amounts.length; i++) {
            require(addresses[i] != address(0), "BulkSender: the list of addresses contains zero address");
            uint256 value = amounts[i];
            require(value != 0, "BulkSender: the list of amounts contains zero value");
            require(value > 0, "BulkSender: the value should be greater then zero");
        }
    }

    receive() external onlyWhiteListed payable {
    }
}