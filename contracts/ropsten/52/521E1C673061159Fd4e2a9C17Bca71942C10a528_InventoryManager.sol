// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./access/Adminable.sol";
import "./items/Traceables.sol";


contract InventoryManager is Adminable, ERC1155Holder {

    Traceables nftcontract;
    string id;

    /**
    * Sets the identification of the company that owns the inventory
    * The administrator address (Veros Address)
    * The ERC1155 smartcontract address 
    */
    constructor(string memory _id, address _admin, address _nftcontract) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        nftcontract = Traceables(_nftcontract);
        id = _id;
    }

    function setTraceablesContract(address _nftcontract) external onlyOwnerOrAdmin {
        nftcontract = Traceables(_nftcontract);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Receiver, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function addItem(uint256 _id, bytes memory _payload, uint256 _amount) external onlyOwnerOrAdmin {
        nftcontract.mint(address(this), _id, _amount, _payload);
    }
}