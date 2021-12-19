// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC20.sol";
import "./Upgradable.sol";
import "./FeeCalculator.sol";
import "./AddressStatusManager.sol";

abstract contract ITFSC {
    function mint(address account, uint256 amount) external virtual;

    function burn(uint256 amount) external virtual;

    function pause() external virtual;

    function unpause() external virtual;

    function setAddressStatusManager(address _addressStatusManager)
        external
        virtual;

    function setFeeCalculator(address _feeCalculator) external virtual;
}

contract TFSC is ITFSC, ERC165, ERC20, Pausable {
    using SafeMath for uint256;

    // Calculator for fee if ever applicable
    IFeeCalculator public feeCalculator;
    AddressStatusManager public addressStatusManager;

    /**
     *  Creates a new Twenty Four Smart contract instance.
     *
     *  Requirements:
     *   - name should be the name of the token
     *   - symbol is the ticker of the token
     *   - initialSupply is the initial amount of tokens to issue
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _addressStatusManager,
        address _feeCalculator
    ) ERC20(name, symbol) {
        feeCalculator = IFeeCalculator(_feeCalculator);
        addressStatusManager = AddressStatusManager(_addressStatusManager);

        _mint(msg.sender, initialSupply);
    }

    function decimals() external view virtual override returns (uint8) {
        return 4;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override whenNotPaused {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 fee = feeCalculator.calculate(amount);
        uint256 sendAmount = amount.sub(fee);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        address feeOwner = feeCalculator.contractOwner();

        _balances[sender] = senderBalance.sub(amount);
        _balances[recipient] = _balances[recipient].add(sendAmount);
        _balances[feeOwner] = _balances[feeOwner].add(fee);

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function mint(address account, uint256 amount) external override onlyOwner {
        _mint(account, amount);
    }

    function burn(uint256 amount) external override onlyOwner {
        _burn(contractOwner(), amount);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /* amount */
    ) internal virtual override {
        require(
            addressStatusManager.statusOf(from) != 1,
            "Transfer: Cannot transfer from blacklisted user"
        );
        require(
            addressStatusManager.statusOf(to) != 1,
            "Transfer: Cannot transfer to blacklisted user"
        );
    }

    function setAddressStatusManager(address _addressStatusManager)
        external
        override
        onlyOwner
    {
        addressStatusManager = AddressStatusManager(_addressStatusManager);
    }

    function setFeeCalculator(address _feeCalculator)
        external
        override
        onlyOwner
    {
        feeCalculator = IFeeCalculator(_feeCalculator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            (interfaceId == type(IERC165).interfaceId) ||
            (interfaceId == type(IERC20).interfaceId);
    }
}