// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

abstract contract AdminManager {
  mapping(string => address) roles;

  modifier onlyOwner(string memory _role) {
    // abi.encodePacked() appends strings
    require(roles[_role] == msg.sender, string(abi.encodePacked("AdminManager: Not", _role)));
    _;
  }

  function onlyOwnerF(string memory _role) internal onlyOwner(_role) { }

  function setupRole(string memory _role, address _owner) public {
    require(roles[_role] == address(0), "AdminManager: RoleAlreadySet");
    roles[_role] = _owner;
  }

  function getRoleOwner(string memory _role) public view returns(address) {
    return roles[_role];
  }

  function safeGetRoleOwner(string memory _role) public view returns(address) {
    address _owner = roles[_role];
    require(_owner != address(0), "AdminManager: RoleNotSet");
    return _owner;
  }

  function transferOwnership(string memory _role, address _newOwner) public onlyOwner(_role) {
    roles[_role] = _newOwner;
  }
}