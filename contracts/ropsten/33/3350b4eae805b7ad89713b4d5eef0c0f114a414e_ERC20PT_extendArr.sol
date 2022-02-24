// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
//import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
//import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20PT_extendArr is ERC20Capped, AccessControl {

    /**
     * OpenZeppelin Access Control
     *
     * Using access control for minting and burning
     * More information:
     * https://docs.openzeppelin.com/contracts/3.x/access-control
     *
     * - `MINTER_ROLE`: Accounts allowed to mint tokens
     * - `MINTED_COINS_RECIEVER_ROLE`: Accounts allowed to recieve freshly minted coins (e.g. custodian)
     * - `BURNER_ROLE`: Accounts allowed to burn tokens
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MINTED_COINS_RECEIVER_ROLE = keccak256("MINTED_COINS_RECEIVER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant METADATA_ADDER_ROLE = keccak256("METADATA_ADDER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        address admin, 
        address metadataAdder, 
        address minter, 
        address mintedCoinReceiver, 
        address burner
    ) 
        ERC20(name_, symbol_) 
        ERC20Capped(1*10**9) { 
        
        /** 
         * Admin can change roles by 
         * - `grantRole()` and 
         * - `revokeRole()`
         * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol
         */
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        _grantRole(METADATA_ADDER_ROLE, metadataAdder);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(MINTED_COINS_RECEIVER_ROLE, mintedCoinReceiver);
        _grantRole(BURNER_ROLE, burner);
    }

    /**
     * Access controlled functions
     */

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        require(hasRole(MINTED_COINS_RECEIVER_ROLE, to), "Reciever is not a receiver for minted coins");
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _burn(_msgSender(), amount);
    }

    function burnerBurn(address account, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _burn(account, amount);
    }


    /**
     * Added URI functionality to contract
     *
     * // Similar concept for ERC1155
     * // Confer for example:
     * // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol
     * 
     * Using extendable array
     * Each array element should be a IPFS metadata hash
     */

    string[] private _uri;
    
    /**
     * URI related functions
     */

    function uri() public view returns (string[] memory) {
        return _uri;
    }

    function addURI(string memory newuri) public virtual {
        require(hasRole(METADATA_ADDER_ROLE, msg.sender), "Caller is not allowed to add metadata");
        _uri.push(newuri);
    }

}