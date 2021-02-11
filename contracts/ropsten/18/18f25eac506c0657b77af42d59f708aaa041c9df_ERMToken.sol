// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "openzeppelin-solidity/contracts/utils/Context.sol";

contract ERMToken is Context, AccessControl, ERC20Pausable{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

constructor(uint256 initialSupply,string memory name_, string memory symbol_, uint8 decimal_) 
public 
ERC20(name_, symbol_) {
        _setupDecimals(decimal_);
        _mint(msg.sender, initialSupply * (10** uint256(decimals())));
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @dev Pauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE` or `DEFAULT_ADMIN_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERMToken: must have pauser/admin role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE` or `DEFAULT_ADMIN_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERMToken: must have pauser/admin role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

}