// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract CtrToken is Ownable, ERC20Burnable, ERC20Pausable {
    uint256 public constant MAX_TOTAL_SUPPLY = 150 * 10**(6 + 18);
    mapping(address => bool) adminList;

    constructor(address wallet) Ownable() ERC20("Creator Platform","CTR") {
        _mint(wallet, MAX_TOTAL_SUPPLY);
        adminList[wallet] = true;
        transferOwnership(wallet);
    }

    /**
     * @dev Throws if called by any account other than the admin.
     */
    modifier onlyAdmins() {
        require(adminList[msg.sender], "Only Admins");
        _;
    }

    /**
     * @dev Set `account` as admin of contract
     */
    function setAdmin(address account, bool value) external onlyOwner {
        adminList[account] = value;
    }

    /**
     * @dev Check `account` is in `adminList` or not
     */
    function isAdmin(address account) public view returns (bool) {
        return adminList[account];
    }

    /**
     * @dev Creates amount tokens and assigns them to account, increasing
     * the total supply.
     *
     * Requirements
     *
     * - account cannot be the zero address.
     */
    function mint(address account, uint256 amount) external onlyAdmins {
        require((ERC20.totalSupply() + amount) <= MAX_TOTAL_SUPPLY, "ERC20: mint amount exceeds MAX_TOTAL_SUPPLY");
        _mint(account, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must be Owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
    * @dev Unpauses all token transfers.
    *
    * See {ERC20Pausable} and {Pausable-_unpause}.
    *
    * Requirements:
    *
    * - the caller must be Owner.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override (ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}