// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract NgageN is AccessControlUpgradeable, ERC1155Upgradeable {
    string private contractUri;
    bytes32 public constant NFT_OPERATOR_ROLE = keccak256("NFT_OPERATOR_ROLE");

    mapping(uint256 => string) private tokenUris;

    // Mapping from account to operator approvals based on token ID
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private operatorTokenApprovals;

    mapping(uint256 => address) public originalCreators;

    event ApprovalForToken(
        address indexed account,
        address indexed operator,
        uint256 indexed tokenID,
        bool approved
    );

    event ApprovalForTokens(
        address indexed account,
        address indexed operator,
        uint256[] indexed tokenID,
        bool approved
    );

    function initialize(string memory _uri, string memory _contractUri)
        public
        initializer
    {
        __ERC1155_init(_uri);
        __AccessControl_init();

        contractUri = _contractUri;
        // DEFAULT_ADMIN_ROLE access role allows to grant and revoke access on any role
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(NFT_OPERATOR_ROLE, _msgSender());
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     @dev modifier to check if the sender is the default admin of NgageN contract
     * Revert if the sender is not the contract admin
     */
    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "NN: Only Admin"
        );
        _;
    }

    /**
     @dev modifier to check if the sender is one of the whitelisted account aka operator
     * Revert if the sender is not an operator
     */
    modifier onlyOperator() {
        require(
            hasRole(NFT_OPERATOR_ROLE, _msgSender()),
            "NN: Only Operator"
        );
        _;
    }

    /**
     * @dev Public function to set URI for all tokens
     * Reverts if the caller is not an admin
     * @param newuri The url that will be set as new URI
     */
    function setURI(string memory newuri) public onlyAdmin {
        require(bytes(newuri).length > 0, "NN: Invalid Base URI");
        _setURI(newuri);
    }

    /**
     * @dev Public function to set URI for particular token
     * Reverts if the caller is not an operator
     * @param id The token id for which uri will be set
     * @param _tokenUri The uri that will be set as new URI
     */
    function setTokenURI(uint256 id, string memory _tokenUri)
        public
        onlyOperator
    {
        require(
            bytes(_tokenUri).length > 0,
            "NN: Invalid Token URI"
        );
        tokenUris[id] = _tokenUri;
    }

    /**
     * @dev Public function to get URI for particular token
     * @param id The token id for which uri will be retrieved
     */
    function uri(uint256 id)
        public
        view
        override
        returns (string memory)
    {
        return
            string(abi.encodePacked(super.uri(id), tokenUris[id]));
    }

    /**
     * @dev Public function to get URI for contract metadata
     */
    function contractURI() public view returns (string memory) {
        return contractUri;
    }

    /**
     * @dev Public function to set URI for contract metadata
     * Reverts if the caller is not an admin
     * @param _contractUri The uri that will be set as new contract metadata URI
     */
    function setContractURI(string memory _contractUri) public onlyAdmin {
        require(
            bytes(_contractUri).length > 0,
            "NN: Invalid Contract URI"
        );
        contractUri = _contractUri;
    }

    /**
     * @dev Public function to mint a single new token
     * Reverts if the caller is not an operator
     * @param to The address to which the newly minted tokens will be assigned.
     * Requirements -
     *   o to cannot be a null address
     *   o if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param id The token id of tokens to be minted
     * @param amount The amount of tokens to be minted for this token id
     * @param _tokenUri The token uri to be set at time of minting
     */
    function mintNFT(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory _tokenUri
    ) external onlyOperator {
        require(
            originalCreators[id] == address(0) || originalCreators[id] == to,
            "NN: Only Original creator"
        );
        require(
            bytes(_tokenUri).length > 0,
            "NN: Invalid Token URI"
        );
        _mint(to, id, amount, data);
        tokenUris[id] = _tokenUri;
        originalCreators[id] = to;
    }

    /**
     * @dev Public function to mint new tokens in batches
     * Reverts if the caller is not an operator
     * Reverts if the length of ids and amounts is not equal
     * @param to The address to which the newly minted tokens will be assigned.
     * Requirements -
     *   o to cannot be a null address
     *   o if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param ids The token ids of tokens to be minted
     * @param amounts The amount of tokens to be minted for respective token id
     * @param _tokenUris The uris of tokens to be set for respective token id
     */
    function mintNFTBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory _tokenUris
    ) external onlyOperator {
        require(
            ids.length == _tokenUris.length,
            "NN: Token IDs and URIs length mismatch"
        );
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                originalCreators[ids[i]] == address(0) ||
                    originalCreators[ids[i]] == to,
                "NN: Only Original creator"
            );
            uint256 _tokenId = ids[i];
            tokenUris[_tokenId] = _tokenUris[i];
            originalCreators[_tokenId] = to;
        }
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Public function to burn existing tokens
     * Reverts if the caller is not an operator
     * @param from The address from which the tokens will be burned.
     * Requirements -
     *   o from cannot be a null address
     *   o from must have at least amount tokens of token type id
     * @param id The token ids of tokens to be burned
     * @param amount The amount of tokens to be burned for mentioned token id
     */
    function burnNFT(
        address from,
        uint256 id,
        uint256 amount
    ) external onlyOperator {
        _burn(from, id, amount);
    }

    /**
     * @dev Public function to burn existing tokens in batches
     * Reverts if the caller is not an operator
     * Reverts if the length of ids and amounts is not equal
     * @param from The address from which the tokens will be burned.
     * Requirements -
     *   o from cannot be a null address
     *   o from must have at least amount tokens of token type id
     * @param ids The token ids of tokens to be burned
     * @param amounts The amount of tokens to be burned for respective token id
     */
    function burnNFTBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external onlyOperator {
        _burnBatch(from, ids, amounts);
    }

    /**
     * @dev Public function to transfer existing tokens of token type ids from one account to another
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *   o to cannot be a null address
     *   o from must have at least amount tokens of token type id
     *   o if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param id The token id of tokens to be transferred
     * @param amount The amount of tokens to be transferred for mentioned token id
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() ||
                isApprovedForAll(from, _msgSender()) ||
                isApprovedForToken(from, _msgSender(), id),
            "NN: caller unapproved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Public function to transfer existing tokens of token type ids from one account to another
     * Reverts if the length of ids and amounts is not equal
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *   o to cannot be a null address
     *   o from must have at least amount tokens of token type id
     *   o if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param ids The token ids of tokens to be transferred
     * @param amounts The amount of tokens to be transferred for respective token id
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        //Add for loop
        require(
            from == _msgSender() ||
                isApprovedForAll(from, _msgSender()) ||
                isApprovedForTokens(from, _msgSender(), ids),
            "NN: caller unapproved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Public function to return the status of tokens approved from account to operator
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param ids The token ids of token to be approved.
     */
    function isApprovedForTokens(
        address account,
        address operator,
        uint256[] memory ids
    ) public view returns (bool) {
        for (uint256 i = 0; i < ids.length; i++) {
            if (operatorTokenApprovals[account][operator][ids[i]] == false) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Public function to return the status of tokens approved from account to operator
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param id The token id of token to be approved.
     */
    function isApprovedForToken(
        address account,
        address operator,
        uint256 id
    ) public view returns (bool) {
        return operatorTokenApprovals[account][operator][id];
    }

    /**
     * @dev Public function to approve existing tokens of particular token id from account to operator
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param id The token id of token to be approved.
     * @param approved The approval status.
     */
    function setApprovalForToken(
        address account,
        address operator,
        uint256 id,
        bool approved
    ) external {
        require(
            _msgSender() == account || hasRole(NFT_OPERATOR_ROLE, _msgSender()),
            "NN: Only operator or token holder"
        );
        operatorTokenApprovals[account][operator][id] = approved;
        emit ApprovalForToken(account, operator, id, approved);
    }

    /**
     * @dev Public function to approve existing tokens of multiple token ids from account to operator
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param ids The token ids of token to be approved.
     * @param approved The approval status.
     */
    function setApprovalForTokens(
        address account,
        address operator,
        uint256[] memory ids,
        bool approved
    ) external {
        require(
            _msgSender() == account || hasRole(NFT_OPERATOR_ROLE, _msgSender()),
            "NN: Only operator or token holder"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            operatorTokenApprovals[account][operator][ids[i]] = approved;
        }
        emit ApprovalForTokens(account, operator, ids, approved);
    }
}