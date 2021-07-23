// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./zeppelin/ERC1155PresetMinterPauser.sol";

// @notice {ERC1155} token with burning, minting, and transfer pausing
contract IsmediaERC1155 is ERC1155PresetMinterPauser {

    /// @notice Grants ADMIN/MINTER/PAUSER role to deployer
    constructor(string memory uri) ERC1155PresetMinterPauser(uri) {
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
    ) public override {
        super.mint(to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        super.mintBatch(to, ids, amounts, data);
    }

    /// @notice Pauses all token transfers. Must have PAUSE role
    function pause() public override {
        super.pause();
    }

    /// @notice Unpauses all token transfers. Must have PAUSE role
    function unpause() public override {
        super.unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
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
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}