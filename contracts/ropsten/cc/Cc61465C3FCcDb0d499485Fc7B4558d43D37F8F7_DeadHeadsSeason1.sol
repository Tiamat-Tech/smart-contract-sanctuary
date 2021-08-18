// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract DeadHeads {
  function ownerOf(uint tokenId) public virtual view returns (address);
  function balanceOf(address owner) external virtual view returns (uint balance);
}

abstract contract DeadTickets {
  function ownerOf(uint tokenId) public virtual view returns (address);
  function balanceOf(address owner) external virtual view returns (uint balance);
  function isApprovedForAll(address _owner, address _operator) external virtual view returns (bool);
  function burn(uint tokenId) public virtual;
}

contract DeadHeadsSeason1 is ERC1155, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint public burnedTickets = 0;
    uint public totalItems;
    uint public maxTicketId;

    DeadHeads _deadHeads;
    DeadTickets _deadTickets;

    event CreateItem(uint itemId, uint ticketsToBurn, uint maxSupply, ItemType itemType);
    enum ItemType { EP, ASSET }
    struct Item {
        uint itemId;
        uint ticketsToBurn;
        uint maxSupply;
        ItemType itemType;
        bool active;
    }

    uint public totalActiveItems;
    
    mapping(address => mapping(uint => bool)) public mintedEpisodes;
    mapping(uint => Item) public items;
    mapping(uint => uint) public totalSupply;

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Restricted to admins.");
        _;
    }

    constructor() ERC1155("https://metadata.com/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _deadHeads = DeadHeads(0xB2F829b80A0e5a34AdA3c93b4b10fFaFDb21e355);
        _deadTickets = DeadTickets(0x53Cdbe0B1C639A4B1a19f409b85387D111574030);
        maxTicketId = 100;
    }

    function _burnTickets(uint[] memory ticketsToBurn) internal {
        require(ticketsToBurn.length == 0 || _deadTickets.isApprovedForAll(msg.sender, address(this)), "contract not approved");
        for (uint i = 0; i < ticketsToBurn.length; i++) {
            require(maxTicketId >= ticketsToBurn[i], "ticket id not allowed yet");
            require(_deadTickets.ownerOf(ticketsToBurn[i]) == msg.sender, "sender does not have this ticket");
        }

        for (uint i = 0; i < ticketsToBurn.length; i++) {
            _deadTickets.burn(ticketsToBurn[i]);
        }
    }

    function activeItems() public view returns (uint[] memory) {
        uint[] memory _activeItems = new uint[](totalActiveItems);
        uint itemIndex;
        for (uint i = 0; i < totalItems; i++) {
            if (items[i].active) {
                _activeItems[itemIndex] = items[i].itemId;
                itemIndex++;
            }
        }
        return _activeItems;
    }


    function hasDeadHeads(address _owner) public view returns (bool) {
        return _deadHeads.balanceOf(_owner) > 0;
    }

    function mintItem(uint itemId, uint[] memory ticketsToBurn) public {
        require(totalItems > itemId, "item does not exists");
        Item storage item = items[itemId];
        if (item.itemType == ItemType.EP) {
            require(mintedEpisodes[msg.sender][itemId] == false, "item already minted by sender");
            require(hasDeadHeads(msg.sender), "caller does not have dead heads");
        }
        require(item.maxSupply == 0 || totalSupply[itemId] < item.maxSupply, "item sold out");
        require(item.ticketsToBurn == ticketsToBurn.length, "required tickets to burn different from sent");
        
        _burnTickets(ticketsToBurn);
        burnedTickets += item.ticketsToBurn;
        totalSupply[itemId]++;
        if (item.itemType == ItemType.EP) mintedEpisodes[msg.sender][itemId] = true;
        _mint(msg.sender, itemId, 1, "");
    }

    function createItem(uint ticketsToBurn, uint maxSupply, ItemType itemType) public onlyAdmin returns (uint) {
        uint index = totalItems;
        items[index] = Item(index, ticketsToBurn, maxSupply, itemType, true);
        totalItems++;
        totalActiveItems++;
        emit CreateItem(index, ticketsToBurn, maxSupply, itemType);
        return index;
    }

    function updateItemTicketsToBurn(uint itemId, uint ticketsToBurn) public onlyAdmin {
        require(totalItems > itemId, "item does not exist");
        items[itemId].ticketsToBurn = ticketsToBurn;
    }

    function updateItemMaxSupply(uint itemId, uint maxSupply) public onlyAdmin {
        require(totalItems > itemId, "item does not exist");
        items[itemId].maxSupply = maxSupply;
    }

    function updateItemActive(uint itemId, bool active) public onlyAdmin {
        require(totalItems > itemId, "item does not exist");

        if (items[itemId].active && !active) totalActiveItems--;
        else if (!items[itemId].active && active) totalActiveItems++;
        items[itemId].active = active;
    }

    function setURI(string memory newURI) external onlyAdmin {
        super._setURI(newURI);
    }

    function setMaxTicketId(uint _maxTicketId) external onlyAdmin {
        maxTicketId = _maxTicketId;
    }

    function addAdmin(address account) public virtual onlyAdmin {
        grantRole(ADMIN_ROLE, account);
    }

    function removeAdmin(address account) public virtual onlyAdmin {
        renounceRole(ADMIN_ROLE, account);
    }
}