// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract Token is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint8 private decimals_;

    event LogNewAlert(string description, address indexed _from, uint256 _n);

    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals,
        uint256 initialAmount
    ) ERC20(name, symbol) {
        decimals_ = _decimals;
        uint256 dec = 10**decimals();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, initialAmount * dec);

        emit LogNewAlert("_rewarded", block.coinbase, block.number);
    }

    function decimals() public view virtual override returns (uint8) {
        return decimals_;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
    }
}