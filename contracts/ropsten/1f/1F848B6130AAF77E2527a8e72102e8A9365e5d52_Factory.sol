// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

import "./Manager.sol";

contract Factory is ERC1155PresetMinterPauser {
    
    address public DAO;
    Manager public manager;

    constructor() ERC1155PresetMinterPauser("Contract wide metadata URI") {
        DAO = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, DAO);
    }
    
    /// @notice Sets `_newManager` as the manager of the contract. Only the current manager can set a new manager.
    function setManager(address _newManager) public {
        require(DAO == msg.sender, "Only the DAO can change the manager.");

        manager = Manager(_newManager);
        grantRole(MINTER_ROLE, _newManager);
    }

    /// @notice Sets the DAO address
    function setDAO(address _newDAO) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only the current default admin can change the admin." );
        require(DAO == address(0) || DAO == msg.sender, "Only the factor manager can call the factory");
        DAO = _newDAO;
    }

    /// @notice Overrides ERC 1155 `uri` function.
    function uri(uint256 _tokenID) public view virtual override returns (string memory) {
        return manager.getTokenURI(_tokenID);
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
        
        require(address(manager) == msg.sender, "Only the factor manager can call the factory");
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
        require(address(manager) == msg.sender, "Only the factor manager can call the factory");
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}