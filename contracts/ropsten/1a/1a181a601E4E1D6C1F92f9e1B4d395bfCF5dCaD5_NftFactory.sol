// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

import "./NftFactoryManager.sol";

contract NftFactory is ERC1155PresetMinterPauser {
 
    address public nftFactoryManager;
    NftFactoryManager public manager;

    constructor() ERC1155PresetMinterPauser("Contract wide metadata URI") {}

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == nftFactoryManager, "Only the factor manager can call the factory");
        _;
    }

    function setAdmin(address _manager) public {
        grantRole(DEFAULT_ADMIN_ROLE, _manager);
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function setFactoryManager(address _newManager) public {
        require(nftFactoryManager == address(0) || nftFactoryManager == msg.sender, "Only the factor manager can call the factory");

        nftFactoryManager = _newManager;
        manager = NftFactoryManager(_newManager);
        grantRole(MINTER_ROLE, _newManager);
        setAdmin(_newManager);
    }

    /// @notice Overrides ERC 1155 `uri` function.
    function uri(uint256 _tokenID) public view virtual override returns (string memory) {
        return manager.getMomentURI(_tokenID);
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
        
        require(nftFactoryManager == msg.sender, "Only the factor manager can call the factory");
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
        require(nftFactoryManager == msg.sender, "Only the factor manager can call the factory");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}