// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./access/Adminable.sol";
import "./interfaces/ICompanyManager.sol";
import "./InventoryManager.sol";
import "./libraries/RolesLibrary.sol";


contract CompanyManager is Adminable, ICompanyManager {

    enum State {Actived, Blocked}

    struct Role {
        bytes32 role;
        bool revoked;
    }

    /**
    * Structs representing every company user/address
    * And its roles in it
    */
    struct WhitelistedAddress {
        address addr;
        mapping(bytes32 => Role) roles;
        State state;
        address createdBy;
        bool exists;
    }

    /**
    * Struct representing a Veros Company
    */
    struct Company {
        string id;
        string name;
        address inventory;
        State state;
        address owner;
        mapping(address => WhitelistedAddress) whitelisted;
        bool exists;
    }

    /**
    * Mapping with all companies controlled by Veros 
    */
    mapping(string => Company) public companies;


    // Events to emit
    event CompanyCreated(string id, string name, address owner, address inventory);
    event RoleGrantedToAddrs(string id, address[] addrs, bytes32 role, address creator);
    event RoleGrantedToAddr(string id, address addr, bytes32 role);


    /**
    * Function used to add a new company 
    * And deploy its inventory contracts
    */
    function addCompany(string memory _idCPMY, string memory _name, address _owner, address _nfts) external onlyOwnerOrAdmin returns (address){
        require(companies[_idCPMY].exists != true, 'Already exists a company with the same ID!');
        InventoryManager _iva = new InventoryManager(_idCPMY, msg.sender, _nfts);
        Company storage _cpmy = companies[_idCPMY];
        _cpmy.id = _idCPMY;
        _cpmy.name = _name;
        _cpmy.inventory = address(_iva);
        _cpmy.state = State.Actived;
        _cpmy.owner = _owner;
        _cpmy.exists = true;

        emit CompanyCreated(_idCPMY, _name, _owner, address(_iva));
        return address(_iva);
    }

    /**
    * Used to add whitelisted address an its roles
    * The "roles" array will be applied for all addrs in the execution
    */
    function grantRoleToAddrs(string memory _idCPMY, address[] memory _addrs, bytes32 _role, address _creator) external onlyOwnerOrAdmin {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        Company storage _cpmy = companies[_idCPMY];

        for (uint i=0; i < _addrs.length; i++) {
            _cpmy.whitelisted[_addrs[i]].addr = _addrs[i];
            _cpmy.whitelisted[_addrs[i]].roles[_role].role = _role;
            _cpmy.whitelisted[_addrs[i]].roles[_role].revoked = false;
            _cpmy.whitelisted[_addrs[i]].state = State.Actived;
            _cpmy.whitelisted[_addrs[i]].createdBy = _creator;
            _cpmy.whitelisted[_addrs[i]].exists = true;
        }

        emit RoleGrantedToAddrs(_idCPMY, _addrs, _role, _creator);
    }
    
    /**
    * Add a new role for a address in whitelist
    */
    function grantRoleToAddr(string memory _idCPMY, address _addr, bytes32 _role) external {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        companies[_idCPMY].whitelisted[_addr].roles[_role].role = _role;
        companies[_idCPMY].whitelisted[_addr].roles[_role].revoked = false;
        emit RoleGrantedToAddr(_idCPMY, _addr, _role);
    }

    /**
    * Revoke a role from an address in whitelist
    */
    function revokeAddrRole(string memory _idCPMY, address _addr, bytes32 _role) external {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        require(companies[_idCPMY].whitelisted[_addr].roles[_role].revoked == false, 'The role is already revoked');
        companies[_idCPMY].whitelisted[_addr].roles[_role].revoked = true;
        emit RoleGrantedToAddr(_idCPMY, _addr, _role);
    }

    function hasAddrRole(string calldata _idCPMY, address _addr, bytes32 _role) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        Role storage _rl = companies[_idCPMY].whitelisted[_addr].roles[_role];
        if(_rl.revoked == true || _rl.role[0] == 0) {
            return false;
        }
        return true;
    }
}