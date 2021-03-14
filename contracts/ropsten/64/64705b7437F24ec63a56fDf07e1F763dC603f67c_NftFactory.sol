// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

contract NftFactory is ERC1155PresetMinterPauser {
 
    address public factoryManager;

    constructor() ERC1155PresetMinterPauser("Contract wide metadata URI") {}

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == factoryManager, "Only the factor manager can call the factory");
        _;
    }
    
    function setFactoryManager(address _newManager) public {
        require(factoryManager == address(0) || factoryManager == msg.sender, "Only the factor manager can call the factory");

        factoryManager = _newManager;
        grantRole(MINTER_ROLE, _newManager);
        // Revoke minter role of deployer
        // Grant DEFAULT_ADMIN_ROLE to DAO account
    }

    /// @notice Overrides ERC 1155 `safeTransferFrom` to check if caller is the factory manager.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        virtual
        override
    {
        
        require(factoryManager == msg.sender, "Only the factor manager can call the factory");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /// @notice Overrides ERC 1155 `safeBatchTransferFrom` to check if caller is the factory manager.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(factoryManager == msg.sender, "Only the factor manager can call the factory");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}