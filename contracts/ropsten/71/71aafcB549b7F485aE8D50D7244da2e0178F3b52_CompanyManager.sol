// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./access/Adminable.sol";
import "./interfaces/ICompanyManager.sol";


contract CompanyManager is Adminable, ICompanyManager {

    /**
    * Available roles for users
    */
    bytes32 public constant ALL_ROLE = keccak256("ALL_ROLE");
    bytes32 public constant CREATE_ROLE = keccak256("CREATE_ROLE");
    bytes32 public constant UPDATE_ROLE = keccak256("UPDATE_ROLE");
    bytes32 public constant DELETE_ROLE = keccak256("DELETE_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /**
    * Available states for a company or address (whitelist)
    */
    bytes32 public constant ACTIVED_STATE = keccak256("ACTIVED_STATE");
    bytes32 public constant BLOCKED_STATE = keccak256("BLOCKED_STATE");

    /**
    * Role structure
    */
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
        bytes32 state;
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
        bytes32 state;
        address owner;
        mapping(address => WhitelistedAddress) whitelisted;
        bool exists;
    }

    /**
    * Mapping with all companies controlled by Veros 
    */
    mapping(string => Company) public companies;

    /**
    * Function used to add a new company 
    * And deploy its inventory contracts
    */
    function addCompany(string memory _idCPMY, string memory _name, address _owner, address _inventory) external onlyOwnerOrAdmin returns (bool){
        require(companies[_idCPMY].exists != true, 'Already exists a company with the same ID!');
        Company storage _cpmy = companies[_idCPMY];
        _cpmy.id = _idCPMY;
        _cpmy.name = _name;
        _cpmy.inventory = _inventory;
        _cpmy.state = ACTIVED_STATE;
        _cpmy.owner = _owner;
        _cpmy.exists = true;

        emit CompanyCreated(_idCPMY, _name, _owner, _inventory);
        return true;
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
            _cpmy.whitelisted[_addrs[i]].state = ACTIVED_STATE;
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

    /**
    * Verify if address has role and if is not revoked
    * Or if user is the company owner
    */
    function hasAddrRole(string calldata _idCPMY, address _addr, bytes32 _role) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        Role storage _rl = companies[_idCPMY].whitelisted[_addr].roles[_role];
        if(!isCompanyOwner(_idCPMY, _addr) && (_rl.revoked == true || _rl.role[0] == 0)) {
            return false;
        }
        return true;
    }

    /**
    * Verify if address has permission to created things for the company
    */
    function isAbleToCreate(string calldata _idCPMY, address _addr) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].state == ACTIVED_STATE, 'The company is blocked');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        WhitelistedAddress storage _wl = companies[_idCPMY].whitelisted[_addr];
        if(!isActived(_wl.state)) {
            return true;
        }
        Role storage _rla = companies[_idCPMY].whitelisted[_addr].roles[ALL_ROLE];
        Role storage _rlc = companies[_idCPMY].whitelisted[_addr].roles[CREATE_ROLE];
        return isCompanyOwner(_idCPMY, _addr) || isValidRole(_rla) || isValidRole(_rlc);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToUpdate(string calldata _idCPMY, address _addr) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].state == ACTIVED_STATE, 'The company is blocked');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        WhitelistedAddress storage _wl = companies[_idCPMY].whitelisted[_addr];
        if(!isActived(_wl.state)) {
            return true;
        }
        Role storage _rla = companies[_idCPMY].whitelisted[_addr].roles[ALL_ROLE];
        Role storage _rlu = companies[_idCPMY].whitelisted[_addr].roles[UPDATE_ROLE];
        return isCompanyOwner(_idCPMY, _addr) || isValidRole(_rla) || isValidRole(_rlu);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToDelete(string calldata _idCPMY, address _addr) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].state == ACTIVED_STATE, 'The company is blocked');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        WhitelistedAddress storage _wl = companies[_idCPMY].whitelisted[_addr];
        if(!isActived(_wl.state)) {
            return true;
        }
        Role storage _rla = companies[_idCPMY].whitelisted[_addr].roles[ALL_ROLE];
        Role storage _rld = companies[_idCPMY].whitelisted[_addr].roles[DELETE_ROLE];
        return isCompanyOwner(_idCPMY, _addr) || isValidRole(_rla) || isValidRole(_rld);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToTransfer(string calldata _idCPMY, address _addr) external view returns (bool) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].state == ACTIVED_STATE, 'The company is blocked');
        require(companies[_idCPMY].whitelisted[_addr].exists == true, 'The address does not exists in this company whitelist');
        WhitelistedAddress storage _wl = companies[_idCPMY].whitelisted[_addr];
        if(!isActived(_wl.state)) {
            return true;
        }
        Role storage _rla = companies[_idCPMY].whitelisted[_addr].roles[ALL_ROLE];
        Role storage _rlt = companies[_idCPMY].whitelisted[_addr].roles[TRANSFER_ROLE];
        return isCompanyOwner(_idCPMY, _addr) || isValidRole(_rla) || isValidRole(_rlt);
    }

    /**
    * Update company inventory
    */
    function setCompanyInventory(string calldata _idCPMY, address _inventory) external onlyOwnerOrAdmin {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        require(companies[_idCPMY].state == ACTIVED_STATE, 'The company is blocked');
        companies[_idCPMY].inventory = _inventory;
        emit CompanyInventoryUpdated(_idCPMY, _inventory);
    }

    /**
    * 
    */
    function getCompanyInfo(string calldata _idCPMY) external view returns (address inventory, bytes32 state, string memory name, address owner) {
        require(companies[_idCPMY].exists == true, 'The company does not exists');
        return (companies[_idCPMY].inventory, companies[_idCPMY].state, companies[_idCPMY].name, companies[_idCPMY].owner);
    }


    /**
    * Return if address is the company owner
    */
    function isCompanyOwner(string calldata _idCPMY, address _addr) internal view returns (bool) {
        return companies[_idCPMY].owner == _addr;
    }

    /**
    * Verify if is valid role
    */
    function isValidRole(Role storage _role) internal view returns(bool) {
        return !_role.revoked && _role.role[0] != 0;
    }

    /**
    * Verify if state is actived
    */
    function isActived(bytes32 state) internal pure returns(bool) {
        return state == ACTIVED_STATE;
    }
}