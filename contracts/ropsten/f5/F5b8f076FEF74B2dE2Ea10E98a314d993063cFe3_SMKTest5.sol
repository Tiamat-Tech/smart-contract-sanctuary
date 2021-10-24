// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//EXTENDED
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract SMKTest5 is Initializable, ERC20Upgradeable, PausableUpgradeable, AccessControlEnumerableUpgradeable, UUPSUpgradeable  {

    
    string private _contractVersion;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");


    function initialize() initializer public virtual{ //RUNS 1st deployment, never on upgrades?

        __ERC20_init("SMKTest5", "SMK5");
        __Pausable_init();
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        
        // __ERC20Permit_init("SMKTest5");
        // __ReentrancyGuard_init();
        // __PullPayment_init();
        
        _contractVersion = "0.0.1";
        //console.log("contractVersion ", _contractVersion); //TODO remove, uses gas, https://hardhat.org/hardhat-network/reference/#console-log
        

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        _setupRole(APPROVER_ROLE, msg.sender);

        _mint(msg.sender, 100000000001 * 10 ** decimals());
        
        
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    

}