// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155.sol";
import "./Ownable.sol";
import "./Strings.sol";
import "./AccessControlEnumerable.sol";
import "./ERC1155Pausable.sol";
import "./ERC1155Burnable.sol";

contract TokenERC1155 is ERC1155, Ownable,AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable {
    


    uint256 public constant lilpeep = 0;
    uint256 public constant xxx = 1;
    uint256 public constant bones = 2;
    uint256 public constant scar = 3;
    
    mapping (uint256 => string) private _uris;

    // constructor() public ERC1155("https://bafybeibfw4ax36cqsvdtmxnl53cijjxu5m7kujtfvbvfunyibz26n4ifye.ipfs.dweb.link/") {
    //     _mint(msg.sender, lilpeep, 1000, "");
    //     _mint(msg.sender, xxx, 1000, "");
    //     _mint(msg.sender, bones, 1000, "");
    //     _mint(msg.sender, scar, 1000, "");
    // }
    
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the account that
     * deploys the contract.
     */
    constructor() ERC1155("https://bafybeibfw4ax36cqsvdtmxnl53cijjxu5m7kujtfvbvfunyibz26n4ifye.ipfs.dweb.link/") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _mint(msg.sender, lilpeep, 1000, "");
        _mint(msg.sender, xxx, 1000, "");
        _mint(msg.sender, bones, 1000, "");
        _mint(msg.sender, scar, 1000, "");
    }
    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
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
        bytes memory data
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mint(to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mintBatch(to, ids, amounts, data);
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