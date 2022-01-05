//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MttmMaToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TRANSFER_ROLE =keccak256("TRANSFER_ROLE");

    constructor() ERC20("MTTM Manager Association", "MTTM-MA") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(TRANSFER_ROLE, msg.sender);


    }

    function transfer(address recipient, uint amount) public virtual override onlyRole(TRANSFER_ROLE) returns(bool){
        return super.transfer(recipient, amount);
    }

    function transferFullToken(address recipient, uint amount) public onlyRole(TRANSFER_ROLE) returns(bool){
        _transfer(msg.sender, recipient, amount*10^18);
        return true;
    }

    function burn(uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount);
    }

    function burnFullToken(uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(msg.sender, amount*10^18);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function mintFullToken(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount*10^18);
    }

    function grantMinter(address grantTo) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, grantTo);
    }

    function revokeMinter(address revokeFrom) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, revokeFrom);
    }

    function grantBurner(address grantTo) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, grantTo);
    }

    function revokeBurner(address revokeFrom) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, revokeFrom);
    }

    function grantTransfert(address grantTo) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(TRANSFER_ROLE, grantTo);
    }

    function revokeTransfer(address revokeFrom) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(TRANSFER_ROLE, revokeFrom);
    }

    function grantAdmin(address grantTo) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, grantTo);
    }

    function revokeAdmin(address revokeFrom) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, revokeFrom);
    }


    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    override(ERC20)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}