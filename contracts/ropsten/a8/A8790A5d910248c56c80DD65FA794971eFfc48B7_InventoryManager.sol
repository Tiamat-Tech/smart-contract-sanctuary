// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./access/Adminable.sol";
import "./interfaces/ICompanyManager.sol";

import "./ItemNFT.sol";

contract InventoryManager is Adminable, Pausable {

    /**
    * Events
    */
    event ItemCreated(string companyId, uint256 itemId, uint256 amount, string payload, address requester);
    event ItemUpdated(string companyId, uint256 itemId, string payload, address requester);
    event ItemEvent(string companyId, uint256 itemId, string payload, address requester);
    event ItemTransfered(string from, string to, uint256 itemId, uint256 amount, address requester);


    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    ItemNFT private currentNFT;
    ICompanyManager private manager;

    mapping(string => mapping(uint256 => uint256)) public tokens;

    /**
    * Sets the identification of the company that owns the inventory
    * The administrator address (Veros Address)
    * The ERC1155 smartcontract address 
    */
    constructor(address erc1155, address companyManager) {
        currentNFT = ItemNFT(erc1155);
        manager = ICompanyManager(companyManager);
    }

    /**
    * Used to mint a new NFT Item
    * It is a Traceable in Veros platform
    */
    function addItem(string memory company, address requester, uint256 amount, string memory payload, string memory timestamp) external whenNotPaused returns (uint256 itemId){
        require(manager.isAbleToCreate(company, requester), "InventoryManager: Address do not have permission to create item");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        currentNFT.mint(_msgSender(), newItemId, amount, '', payload, requester, timestamp);
        tokens[company][newItemId] = amount;
        emit ItemCreated(company, newItemId, amount, payload, requester);
        return newItemId;
    }

    /**
    * Function to set tracker when an item is updated
    */
    function setUpdated(string memory company, uint256 itemId, string memory payload, address requester, string memory timestamp) external whenNotPaused {
        require(manager.isAbleToUpdate(company, requester), "InventoryManager: Address do not have permission to create item");
        require(tokens[company][itemId] > 0, "InventoryManager: Company does not have enought amount for this item");

        currentNFT.setTracker(_msgSender(), itemId, payload, requester, timestamp);
        emit ItemUpdated(company, itemId, payload, requester);

    }

    /**
    *   Called every time an event is created or updated
    */
    function setEvent(string memory company, uint256 itemId, uint256 eventId, string memory payload, address requester, string memory timestamp) external whenNotPaused {
        require(manager.isAbleToUpdate(company, requester), "InventoryManager: Address do not have permission to create item");
        require(tokens[company][itemId] > 0, "InventoryManager: Company does not have enought amount for this item");
        currentNFT.setEventTracker(_msgSender(), itemId, eventId, payload, requester, timestamp);
        emit ItemEvent(company, itemId, payload, requester);

    }

    /**
    *   Function to set tracker when an item is updated
    */
    function setUpdatedBatch(string memory company, uint256[] memory itemIds, string[] memory payloads, address requester, string memory timestamp) external whenNotPaused {
        require(manager.isAbleToUpdate(company, requester), "InventoryManager: Address do not have permission to create item");
        currentNFT.setTrackerBatch(_msgSender(), itemIds, payloads, requester, timestamp);
    }

    /**
    *   Transfer to another company
    */
    function transfer(string memory from_company, string memory to_company, address requester, address to, uint256 itemId, uint256 amount) external whenNotPaused {
        require(manager.isAbleToTransfer(from_company, requester), "InventoryManager: Address do not have permission to create item");
        require(tokens[from_company][itemId] > 0, "InventoryManager: Company does not have enought amount for this item");
        require(tokens[from_company][itemId] - amount >= 0, "InventoryManager: Company does not have enought amount for this item");
        require(manager.isCompanyActived(to_company), "InventoryManager: To campany is not actived");

        currentNFT.safeTransferFrom(_msgSender(), to, itemId, amount, '');
        tokens[from_company][itemId] = tokens[from_company][itemId] - amount;
        tokens[to_company][itemId] = tokens[to_company][itemId] + amount;
        emit ItemTransfered(from_company, to_company, itemId, amount, requester);
    }
}