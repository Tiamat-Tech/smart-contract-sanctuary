// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./IENSResolver.sol";


contract Pass3Resolver is  ERC165, Ownable, IENSResolver    {

    // ============ Interfaces ============
    bytes4 constant private ADDRESS_INTERFACE_ID = bytes4(keccak256("addr(bytes32)"));
    bytes4 constant private NAME_INTERFACE_ID = bytes4(keccak256("name(bytes32)"));
    
    // ============ Structs ============
    struct Record {
        address addr;
        string name;
    }

    // ============ Mappings ============

    // mapping between namehash and resolved records
    mapping(bytes32 => Record) records;

    
    // ============ Public Functions ============

    /**
     * @notice Lets the manager set the address associated with an ENS node.
     * @param _node The node to update.
     * @param _addr The address to set.
     */
    function setAddr(bytes32 _node, address _addr) public override onlyOwner {
        records[_node].addr = _addr;
        emit AddrChanged(_node, _addr);
    }

    /**
     * @notice Lets the manager set the name associated with an ENS node.
     * @param _node The node to update.
     * @param _name The name to set.
     */
    function setName(bytes32 _node, string memory _name)
        public
        override
        onlyOwner
    {
        records[_node].name = _name;
        emit NameChanged(_node, _name);
    }

    /**
     * @notice Gets the address associated to an ENS node.
     * @param _node The target node.
     * @return the address of the target node.
     */
    function addr(bytes32 _node) public view override returns (address) {
        return records[_node].addr;
    }

    /**
     * @notice Gets the name associated to an ENS node.
     * @param _node The target ENS node.
     * @return the name of the target ENS node.
     */
    function name(bytes32 _node) public view override returns (string memory) {
        return records[_node].name;
    }
    
    function supportsInterface(bytes4 _interfaceId) override public view returns (bool) {
        return _interfaceId == ADDRESS_INTERFACE_ID ||
                _interfaceId == NAME_INTERFACE_ID ||
                super.supportsInterface(_interfaceId);
    }
    
}