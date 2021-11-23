// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact [email protected]
contract Bazik is AccessControlUpgradeable, ERC20VotesUpgradeable, PausableUpgradeable, UUPSUpgradeable {
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	/// @custom:oz-upgrades-unsafe-allow constructor
	// solhint-disable-next-line no-empty-blocks
	constructor() initializer {}

	function initialize() public initializer {
		__ERC20_init("Bazik", "BZK");
		__Pausable_init();
		__AccessControl_init();
		__ERC20Permit_init("BazikDefi");
		__UUPSUpgradeable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(MINTER_ROLE, msg.sender);
		_setupRole(PAUSER_ROLE, msg.sender);
		_setupRole(UPGRADER_ROLE, msg.sender);
		_mint(msg.sender, 1000000 * 10**decimals());
	}

	/**
	 * @dev Destroys `amount` tokens from the caller.
	 *
	 * See {ERC20-_burn}.
	 */
	function burn(uint256 amount) public virtual {
		_burn(_msgSender(), amount);
	}

	/**
	 * @dev Destroys `amount` tokens from `account`, deducting from the caller's
	 * allowance.
	 *
	 * See {ERC20-_burn} and {ERC20-allowance}.
	 *
	 * Requirements:
	 *
	 * - the caller must have allowance for ``accounts``'s tokens of at least
	 * `amount`.
	 */
	function burnFrom(address account, uint256 amount) public virtual {
		uint256 currentAllowance = allowance(account, _msgSender());
		require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
		unchecked {
			_approve(account, _msgSender(), currentAllowance - amount);
		}
		_burn(account, amount);
	}

	/**
	 * @dev Triggers stopped state.
	 *
	 * Requirements:
	 *
	 * - The contract must not be paused.
	 * - The caller must have PAUSER_ROLE
	 */
	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	/**
	 * @dev Returns to normal state.
	 *
	 * Requirements:
	 *
	 * - The contract must be paused.
	 * - The caller must have PAUSER_ROLE
	 */
	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	/** @dev Creates `amount` tokens and assigns them to `account`, increasing
	 * the total supply.
	 *
	 * Emits a {Transfer} event with `from` set to the zero address.
	 *
	 * Requirements:
	 *
	 * - The receiver cannot be the zero address.
	 * - The caller must have MINTER_ROLE
	 */
	function mint(address receiver, uint256 amount) public onlyRole(MINTER_ROLE) {
		_mint(receiver, amount);
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override whenNotPaused {
		super._beforeTokenTransfer(from, to, amount);
	}

	// solhint-disable-next-line no-empty-blocks
	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}