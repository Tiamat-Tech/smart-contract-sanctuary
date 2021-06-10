pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HugToken is ERC20, AccessControl {

    bytes32 public constant BURNER_ROLE = keccak256(abi.encode("BURNER_ROLE"));

    /**
     * Constructor for Hug Token
     * Mints total fixed supply
     * Sets up contract creator as the burner
     * Sets up an admin role, so utilty accounts can become burners
     */
    constructor() ERC20("HugToken1", "HUG1") {
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
      _mint(msg.sender, 150000000 * 10 ** decimals());
    }


    /**
     * Implement the burn method requiring the BURNER_ROLE
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

}