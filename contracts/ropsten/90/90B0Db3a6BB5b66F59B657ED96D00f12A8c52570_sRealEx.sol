// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// No SafeMath needed for Solidity 0.8+
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract sRealEx is ERC20, ERC20Snapshot, AccessControl, Pausable {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bool public minted = false;

    uint256 maxSupply = 0;

    // accepts initial supply in whole numbers and adds decimal places of the token automatically
    constructor(uint256 _maxSupply, address adminRole, address snapshotRole, address pauserRole, address burnerRole, address minterRole) ERC20("Seed RealEx", "SREALEX") {
        _setupRole(DEFAULT_ADMIN_ROLE, adminRole);
        _setupRole(SNAPSHOT_ROLE, snapshotRole);
        _setupRole(PAUSER_ROLE, pauserRole);
        _setupRole(BURNER_ROLE, burnerRole);
        _setupRole(MINTER_ROLE, minterRole);

        maxSupply = _maxSupply * 10 ** decimals();
    }
    
    // Can only mint once to whatever was set in the constructor
    function mint() public onlyRole(MINTER_ROLE) {
        require(minted == false, "ALREADY_MINTED_MAX_SUPPLY");
        minted = true;
        _mint(msg.sender, maxSupply);
    }

    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount * 10 ** decimals());
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}