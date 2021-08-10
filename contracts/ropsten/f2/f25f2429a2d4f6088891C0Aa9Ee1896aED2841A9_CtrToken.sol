// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";

contract CtrToken is ERC20, AccessControl {
    uint256 public constant MAX_TOTAL_SUPPLY = 150 * 10**(6 + 18);
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(address wallet) ERC20("Creator Chain","CTR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(wallet, MAX_TOTAL_SUPPLY);
    }

    /**
     * @dev Creates amount tokens and assigns them to account, increasing
     * the total supply.
     *
     * Requirements
     *
     * - account cannot be the zero address.
     */
    function mint(address account, uint256 amount) public onlyRole(MINTER_ROLE) {
        require((ERC20.totalSupply() + amount) <= MAX_TOTAL_SUPPLY, "ERC20: mint amount exceeds MAX_TOTAL_SUPPLY");
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }
}