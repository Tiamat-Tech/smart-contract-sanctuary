// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libraries/ERC20.sol";

contract VitaminToken is ERC20 {
    // The operator can only unlock token for trading one time
    address private _operator;

    // for locking public trading
    bool public locked;
    mapping(address => bool) lockWhiteList;

    // Events
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);
    event MaxTransferAmountRateUpdated(address indexed operator, uint256 previousRate, uint256 newRate);

    modifier onlyOperator() {
        require(_operator == msg.sender, "operator: caller is not the operator");
        _;
    }


    /**
     * @notice Constructs the VitaminToken contract.
     */
    constructor() public ERC20("Vitamin Test", "VITT") {
        // mint total supply - supply fixed, can never be minted again
        _mint(msg.sender, 10000 ether);

        // lock transfers
        locked = true;

        // only owner whitelisted
        lockWhiteList[msg.sender] = true;

        _operator = _msgSender();
        emit OperatorTransferred(address(0), _operator);
    }


    /// @dev overrides transfer function to meet tokenomics of vitamin
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        if (locked && !lockWhiteList[sender]) revert("Locked for xfer");

        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) public onlyOperator {
        require(newOperator != address(0), "VITAMIN::transferOperator: new operator is the zero address");
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }

    // unlocks public trading - cannot be relocked
    function unlockTrading() public onlyOperator {
        locked = false;
    }

}