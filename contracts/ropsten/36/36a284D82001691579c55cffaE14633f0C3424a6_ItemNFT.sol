// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./extensions/WithTracker.sol";
import "./extensions/WithEventsTracker.sol";



contract ItemNFT is Context, AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable, WithTracker, WithEventsTracker {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the account that
     * deploys the contract.
     */
    constructor(string memory uri) ERC1155(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(UPDATER_ROLE, _msgSender());
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory payload,
        address creator,
        string memory timestamp
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");
        _mint(to, id, amount, data);
        _setTracker(id, creator, payload, timestamp);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory payloads,
        address creator,
        string memory timestamp
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");
        _mintBatch(to, ids, amounts, data);
        for(uint i=0; i < ids.length; i++) {
            _setTracker(ids[i], creator, payloads[i], timestamp);
        }
    }

    /**
    * Function used to update Item History/track
    * Only address with correct permission can use this function
    *
    * It will be called every time an Item at Veros Plataform is updated
    */
    function setTracker (
        uint256 id,
        string memory payload,
        address creator,
        string memory timestamp
    ) public virtual {
        require(hasRole(UPDATER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have updater role to add a new Item Tracker");
        _setTracker(id, creator, payload, timestamp);
    }

    /**
    * Function used to create an Item History/track
    * Only address with correct permission can use this function
    *
    * It will be called every time an Item at Veros Plataform is updated
    */
    function setTrackerBatch (
        uint256[] memory ids,
        string[] memory payloads,
        address creator,
        string memory timestamp
    ) public virtual {
        require(hasRole(UPDATER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have updater role to add a new Item Tracker");
        for(uint i=0; i < ids.length; i++) {
            _setTracker(ids[i], creator, payloads[i], timestamp);
        }
    }

    /**
    * Function used to create a Event History/track
    * Only address with correct permission can use this function
    *
    * It will be called every time an Event at Veros Plataform is created or updated
    */
    function setEventTracker (
        uint256 itemId,
        uint256 eventId,
        string memory payload,
        address creator,
        string memory timestamp
    ) public virtual {
        require(hasRole(UPDATER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have updater role to add a new Event Tracker");
        _setEventTracker(itemId, eventId, creator, payload, timestamp);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}