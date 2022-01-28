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
        bool allpermitted; //Any address can create, update, transfer or delete
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
    function addCompany(string memory company, string memory name, address owner, address inventory, bool allpermitted) external onlyOwnerOrAdmin returns (bool){
        require(companies[company].exists != true, 'CompanyManager: Already exists a company with the same ID!');
        Company storage _cpmy = companies[company];
        _cpmy.id = company;
        _cpmy.name = name;
        _cpmy.inventory = inventory;
        _cpmy.state = ACTIVED_STATE;
        _cpmy.owner = owner;
        _cpmy.allpermitted = allpermitted;
        _cpmy.exists = true;

        emit CompanyCreated(company, name, owner, inventory);
        return true;
    }

    /**
    * Used to change companies owner
    */
    function setCompanyOwner(string memory company, address owner) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        Company storage _cpmy = companies[company];
        _cpmy.owner = owner;
        emit CompanyOwnerChanged(company, owner);
    }

    /**
    * Used to add whitelisted address an its roles
    * The "roles" array will be applied for all addrs in the execution
    */
    function grantRoleToAddrs(string memory company, address[] memory whitelisted, bytes32 role, address creator) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].allpermitted != true, 'CompanyManager: The company does not have whitelist feature enable');

        Company storage _cpmy = companies[company];

        for (uint i=0; i < whitelisted.length; i++) {
            WhitelistedAddress storage _cl = _cpmy.whitelisted[whitelisted[i]];
            if(!_cl.exists) {
                _cl.addr = whitelisted[i];
                _cl.state = ACTIVED_STATE;
                _cl.createdBy = creator;
                _cl.exists = true;
            }

            _cl.roles[role].role = role;
            _cl.roles[role].revoked = false;
        }

        emit RoleGrantedToAddrs(company, whitelisted, role, creator);
    }
    
    /**
    * Add a new role for a address in whitelist
    */
    function grantRoleToAddr(string memory company, address whitelisted, bytes32 role, address creator) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].allpermitted != true, 'CompanyManager: The company does not have whitelist feature enable');

        WhitelistedAddress storage _cl = companies[company].whitelisted[whitelisted];

        if(!_cl.exists) {
            _cl.addr = whitelisted;
            _cl.state = ACTIVED_STATE;
            _cl.createdBy = creator;
            _cl.exists = true;
        }
            
        _cl.roles[role].role = role;
        _cl.roles[role].revoked = false;
        emit RoleGrantedToAddr(company, whitelisted, role);
    }

    /**
    * Revoke a role from an address in whitelist
    */
    function revokeAddrRole(string memory company, address whitelisted, bytes32 role) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].allpermitted != true, 'CompanyManager: The company does not have whitelist feature enable');
        require(companies[company].whitelisted[whitelisted].exists == true, 'CompanyManager: The address does not exists in this company whitelist');
        require(companies[company].whitelisted[whitelisted].roles[role].revoked == false, 'CompanyManager: The role is already revoked');
        companies[company].whitelisted[whitelisted].roles[role].revoked = true;
        emit RoleGrantedToAddr(company, whitelisted, role);
    }

    /**
    * Used to block or active a address in whitelist
    */
    function changeAddrState(string memory company, address whitelisted, bytes32 state) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].allpermitted != true, 'CompanyManager: The company does not have whitelist feature enable');
        require(companies[company].whitelisted[whitelisted].exists == true, 'CompanyManager: The address does not exists in this company whitelist');
        require(isValidState(state), 'CompanyManager: The state is not valid for this contract. Only accept ACTIVED_STATE and BLOCKED_STATE');
        companies[company].whitelisted[whitelisted].state = state;
        emit AddressStateChanged(company, whitelisted, state);
    }

    /**
    * Used to block or active a company
    */
    function changeCompanyState(string memory company, bytes32 state) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(isValidState(state), 'CompanyManager: The state is not valid for this contract. Only accept ACTIVED_STATE and BLOCKED_STATE');
        companies[company].state = state;
        emit CompanyStateChanged(company, state);
    }

    /**
    * Verify if address has role and if is not revoked
    * Or if user is the company owner
    */
    function hasAddrRole(string calldata company, address whitelisted, bytes32 role) external view returns (bool) {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].whitelisted[whitelisted].exists == true, 'CompanyManager: The address does not exists in this company whitelist');
        Role storage _rl = companies[company].whitelisted[whitelisted].roles[role];
        if(!isCompanyOwner(company, whitelisted) && (_rl.revoked == true || _rl.role[0] == 0)) {
            return false;
        }
        return true;
    }

    /**
    * Verify if address has permission to created things for the company
    */
    function isAbleToCreate(string calldata company, address whitelisted) external view returns (bool) {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].state == ACTIVED_STATE, 'CompanyManager: The company is blocked');
        
        if(companies[company].allpermitted) {
            return true;
        }

        WhitelistedAddress storage _wl = companies[company].whitelisted[whitelisted];

        if(isCompanyOwner(company, whitelisted)) {
            return true;
        }

        if(!isActived(_wl.state)) {
            return false;
        }

        Role storage _rla = companies[company].whitelisted[whitelisted].roles[ALL_ROLE];
        Role storage _rlc = companies[company].whitelisted[whitelisted].roles[CREATE_ROLE];
        return isValidRole(_rla) || isValidRole(_rlc);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToUpdate(string calldata company, address whitelisted) external view returns (bool) {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].state == ACTIVED_STATE, 'CompanyManager: The company is blocked');

        if(companies[company].allpermitted) {
            return true;
        }

        WhitelistedAddress storage _wl = companies[company].whitelisted[whitelisted];
        
        if(isCompanyOwner(company, whitelisted)) {
            return true;
        }

        if(!isActived(_wl.state)) {
            return false;
        }

        Role storage _rla = companies[company].whitelisted[whitelisted].roles[ALL_ROLE];
        Role storage _rlu = companies[company].whitelisted[whitelisted].roles[UPDATE_ROLE];
        return isValidRole(_rla) || isValidRole(_rlu);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToDelete(string calldata company, address whitelisted) external view returns (bool) {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].state == ACTIVED_STATE, 'CompanyManager: The company is blocked');
        
        if(companies[company].allpermitted) {
            return true;
        }
        
        WhitelistedAddress storage _wl = companies[company].whitelisted[whitelisted];
        
        if(isCompanyOwner(company, whitelisted)) {
            return true;
        }

        if(!isActived(_wl.state)) {
            return false;
        }

        Role storage _rla = companies[company].whitelisted[whitelisted].roles[ALL_ROLE];
        Role storage _rld = companies[company].whitelisted[whitelisted].roles[DELETE_ROLE];
        return isValidRole(_rla) || isValidRole(_rld);
    }

    /**
    * Verify if address has permission to update things for the company
    */
    function isAbleToTransfer(string calldata company, address whitelisted) external view returns (bool) {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].state == ACTIVED_STATE, 'CompanyManager: The company is blocked');
        
        if(companies[company].allpermitted) {
            return true;
        }
        
        WhitelistedAddress storage _wl = companies[company].whitelisted[whitelisted];
        
        if(isCompanyOwner(company, whitelisted)) {
            return true;
        }

        if(!isActived(_wl.state)) {
            return false;
        }

        Role storage _rla = companies[company].whitelisted[whitelisted].roles[ALL_ROLE];
        Role storage _rlt = companies[company].whitelisted[whitelisted].roles[TRANSFER_ROLE];
        return isValidRole(_rla) || isValidRole(_rlt);
    }

    /**
    * Update company inventory
    */
    function setCompanyInventory(string calldata company, address inventory) external onlyOwnerOrAdmin {
        require(companies[company].exists == true, 'CompanyManager: The company does not exists');
        require(companies[company].state == ACTIVED_STATE, 'CompanyManager: The company is blocked');
        companies[company].inventory = inventory;
        emit CompanyInventoryUpdated(company, inventory);
    }

    /**
    * Return if address is the company owner
    */
    function isCompanyOwner(string calldata company, address whitelisted) internal view returns (bool) {
        return companies[company].owner == whitelisted;
    }

    /**
    * Verify if is valid role
    */
    function isValidRole(Role storage role) internal view returns(bool) {
        return !role.revoked && role.role[0] != 0;
    }

    /**
    * Verify if state is actived
    */
    function isActived(bytes32 state) internal pure returns(bool) {
        return state == ACTIVED_STATE;
    }

    /**
    * Return true if company is actived
    */
    function isCompanyActived(string calldata company) external view returns(bool) {
        return companies[company].state == ACTIVED_STATE;
    }

    /**
    * Verify if state is actived
    */
    function isValidState(bytes32 state) internal pure returns(bool) {
        return state == ACTIVED_STATE || state == BLOCKED_STATE;
    }
}