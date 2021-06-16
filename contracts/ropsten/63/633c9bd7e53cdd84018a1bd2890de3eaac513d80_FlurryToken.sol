//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20PresetMinterPauserUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20CappedUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FlurryToken is ERC20PresetMinterPauserUpgradeable, ERC20CappedUpgradeable {
    using SafeMathUpgradeable for uint256;

    // Token
    uint256 public constant MAX_SUPPLY = 1e28;

    // Role
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    // Initilizer
    function initialize(string memory name, string memory symbol) public override initializer {
        ERC20PresetMinterPauserUpgradeable.__ERC20PresetMinterPauser_init(name, symbol);
        ERC20CappedUpgradeable.__ERC20Capped_init_unchained(MAX_SUPPLY);
    }

    // TODO - Governance

    /// @notice A record of states for signing / validating signatures
    // mapping(address => uint256) public nonces;



    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        _mint(to, amount);
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        require(totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }

    /**
     * @dev Multiple inheritance for _beforeTokenTransfer.
     * Need to override all functions with the same signature in the parents
     * All the parent implementations however, does nothing substantial.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Upgradeable, ERC20PresetMinterPauserUpgradeable) {
        ERC20PresetMinterPauserUpgradeable._beforeTokenTransfer(from, to, amount);
    }

    function sweepERC20Token(address token,address to)external onlyRole(SWEEPER_ROLE){
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

}