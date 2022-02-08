// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./INgageN.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "./CustomForwarder.sol";

contract ProofOfX is AccessControl, ERC2771Context {
    bytes32 public constant CREATOR = keccak256("CREATOR");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");
    INgageN public nftAddress;

    /**
     * @dev Constructor for ProofOfX contract
     * @param _nftAddress address of the NFT contract
     * @param _forwarder CustomForwarder instance address for ERC2771Context constructor
     */
    constructor(INgageN _nftAddress, CustomForwarder _forwarder)
        ERC2771Context(address(_forwarder))
    {
        nftAddress = _nftAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     @dev modifier to check if the sender is the default admin of PoX contract
     * Revert if the sender is not the admin
     */
    modifier onlyPoXAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "PoX: Only Admin"
        );
        _;
    }

    /**
     @dev modifier to check if the sender is the trusted forwarder
     * Revert if the sender is not the trusted forwarder
     */
    modifier onlyTrustedForwarder() {
        require(
            isTrustedForwarder(msg.sender),
            "PoX: Only Trusted Forwarder"
        );
        _;
    }


    /**
     @dev Overriding _msgSender function inherited from Context and ERC2771Context
     */
    function _msgSender()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (address)
    {
        return ERC2771Context._msgSender();
    }

    /**
     @dev Overriding _msgData function inherited from Context and ERC2771Context
     */
    function _msgData()
        internal
        view
        virtual
        override(Context, ERC2771Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /**
     * @dev Public function to set NFT address for NgageN interface
     * Reverts if the caller is not admin
     * @param _nftAddress The address that will be set as new NFT address for NgageN interface
     */
    function setNFTAddress(address _nftAddress) public onlyPoXAdmin {
        require(
            _nftAddress != address(0),
            "PoX: Invalid address"
        );
        nftAddress = INgageN(_nftAddress);
    }

    /**
     * @dev Public function to set Token URI of particular token id
     * Reverts if the caller is not admin
     * @param id The token id of token 
     * @param _tokenUri new token uri of token to be set
     */
    function setTokenURI(uint256 id, string memory _tokenUri)
        public
        onlyPoXAdmin
    {
        nftAddress.setTokenURI(id, _tokenUri);
    }

    /**
     * @dev Public function to get URI for particular token
     * @param id The token id for which uri will be retrieved
     */
    function getTokenURI(uint256 id) public view returns (string memory) {
        return nftAddress.uri(id);
    }

    /**
     * @dev Public function to mint a single new token
     * Reverts if the caller is not trusted forwarder contract
     * @param to The address to which the newly minted tokens will be assigned.
     * Requirements -
     *   to cannot be a null address
     *   if to is a contract address then it must implement IERC1155Receiver.onERC1155Received and return the magic acceptance value
     * @param id The token id of tokens to be minted
     * @param amount The amount of tokens to be minted for this token id
     * @param data The data to be stored in the token
     */
    function mintNFT(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory _tokenUri
    ) public onlyTrustedForwarder {
        require(
            hasRole(CREATOR, to) && (to == _msgSender()),
            "PoX: Only CREATOR with valid signature"
        );
        nftAddress.mintNFT(to, id, amount, data, _tokenUri);
        if (!nftAddress.isApprovedForToken(to, address(this), id)) {
            nftAddress.setApprovalForToken(to, address(this), id, true);
        }
    }

    /**
     * @dev Public function to burn existing tokens
     * Reverts if the caller is not PoX Admin
     * @param from The address from which the tokens will be burned.
     * Requirements -
     * from cannot be a null address
     * from must have at least amount tokens of token type id
     * @param id The token ids of tokens to be burned
     * @param amount The amount of tokens to be burned for mentioned token id
     */
    function burnNFT(
        address from,
        uint256 id,
        uint256 amount
    ) public onlyPoXAdmin {
        nftAddress.burnNFT(from, id, amount);
    }

    /**
     * @dev Public function to transfer existing tokens of token type id from one account to another
     * Reverts if the caller is not trusted forwarder contract
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *      to cannot be a null address
     *      from must have at least amount tokens of token type id
     *      if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param id The token id of tokens to be transferred
     * @param amount The amount of tokens to be transferred for mentioned token id
     * @param data The data to be stored in the token
     */
    function transferNFT(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyTrustedForwarder {
        require(
            hasRole(OPERATOR, _msgSender()),
            "PoX: Only OPERATOR with valid signature"
        );
        nftAddress.safeTransferFrom(from, to, id, amount, data);
    }


    /**
     * @dev Public function to approve & transfer existing tokens of token type id from one account to another
     * Reverts if the caller is not trusted forwarder contract
     * Reverts if the original msgSender() is not token owner
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *      to cannot be a null address
     *      from must have at least amount tokens of token type id
     *      if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param id The token id of tokens to be transferred
     * @param amount The amount of tokens to be transferred for mentioned token id
     * @param data The data to be stored in the token
     */
    function approveAndTransferNFT(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyTrustedForwarder {
        require(from == _msgSender(), "PoX: Only token owner with valid signature");
        if (!nftAddress.isApprovedForToken(from, address(this), id)) {
            nftAddress.setApprovalForToken(from, address(this), id, true);
        }
        nftAddress.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Public function to mint new tokens in batches
     * Reverts if the caller is not trusted forwarder contract
     * Reverts if the length of ids and amounts is not equal
     * @param to The address to which the newly minted tokens will be assigned.
     * Requirements -
     *   to cannot be a null address
     *   if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param ids The token ids of tokens to be minted
     * @param amounts The amount of tokens to be minted for respective token id
     * @param data The data to be stored in the token
     */
    function mintNFTBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory _tokenUris
    ) public onlyTrustedForwarder {
        require(
            hasRole(CREATOR, to) && (to == _msgSender()),
            "PoX: Only CREATOR with valid signature"
        );
        nftAddress.mintNFTBatch(to, ids, amounts, data, _tokenUris);
        if (!nftAddress.isApprovedForTokens(to, address(this), ids)) {
            nftAddress.setApprovalForTokens(to, address(this), ids, true);
        }
    }

    /**
     * @dev Public function to burn existing tokens in batches
     * Reverts if the caller is not PoX Admin
     * Reverts if the length of ids and amounts is not equal
     * @param to The address from which the tokens will be burned.
     * Requirements -
     *      to cannot be a null address
     *      to must have at least amount tokens of token type id
     * @param ids The token ids of tokens to be burned
     * @param amounts The amount of tokens to be burned for respective token id
     */
    function burnNFTBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public onlyPoXAdmin {
        nftAddress.burnNFTBatch(to, ids, amounts);
    }

    /**
     * @dev Public function to transfer existing tokens of token type ids from one account to another
     * Reverts if the caller is not trusted forwarder contract
     * Reverts if the length of ids and amounts is not equal
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *       to cannot be a null address
     *       from must have at least amount tokens of token type id
     *       if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param ids The token ids of tokens to be transferred
     * @param amounts The amount of tokens to be transferred for respective token id
     */
    function transferNFTBatch(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyTrustedForwarder {
        require(
            hasRole(OPERATOR, _msgSender()),
            "PoX: Only OPERATOR valid signature"
        );
        nftAddress.safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    /**
     * @dev Public function to approve & transfer existing tokens of token type ids from one account to another
     * Reverts if the caller is not trusted forwarder contract
     * Reverts if the original msgSender() is not token owner
     * @param from The address from which the tokens transfer will be occur.
     * @param to The address which will receive the tokens.
     * Requirements -
     *       to cannot be a null address
     *       from must have at least amount tokens of token type id
     *       if to is a contract address than it must implement IERC1155Receiver.onERC1155Received and returns the magic acceptance value
     * @param ids The token ids of tokens to be transferred
     * @param amounts The amount of tokens to be transferred for respective token id
     */
    function approveAndTransferNFTBatch(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyTrustedForwarder {
        require(from == _msgSender(), "PoX: Only token owner with valid signature");
        nftAddress.setApprovalForTokens(from, address(this), ids, true);
        nftAddress.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Public function to access the total balance for an address for an tokenId
     * @param account The address for which the total balance will be returned
     * @param id The tokenId for which the total balance will be returned
     * @return The total balance for the account and tokenId
     */
    function balanceOf(address account, uint256 id)
        public
        view
        returns (uint256)
    {
        return nftAddress.balanceOf(account, id);
    }

    /**
     @dev Public function to access the total balances for an array of addresses for an array of tokenId's
     * @param accounts The array of addresses for which the total balances will be returned
     * @param ids The array of tokenId's for which the total balances will be returned
     * @return The array of total balances for each address for each tokenId
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        public
        view
        returns (uint256[] memory)
    {
        return nftAddress.balanceOfBatch(accounts, ids);
    }

    /**
     * @dev Public function to approve existing tokens of particular token id from account to operator
     * reverts if the caller is not trusted forwarder contract
     * also account must be the transaction signer and with creator access
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
    ) public onlyTrustedForwarder {
        require(account == _msgSender(), "PoX: Only token owner with valid signature");
        nftAddress.setApprovalForToken(account, operator, id, approved);
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
        return nftAddress.isApprovedForToken(account, operator, id);
    }

    /**
     * @dev Public function to approve existing tokens of multiple token ids from account to operator
     * reverts if the caller is not a trusted forwarder contract
     * also account must be the transaction signer and with creator access
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param ids The token id of tokens to be approved.
     * @param approved The approval status.
     */
    function setApprovalForTokens(
        address account,
        address operator,
        uint256[] memory ids,
        bool approved
    ) public onlyTrustedForwarder {
        require(account == _msgSender(), "PoX: Only token owner with valid signature");
        nftAddress.setApprovalForTokens(account, operator, ids, approved);
    }

    /**
     * @dev Public function to return the status of tokens approved from account to operator
     * @param account The address from which the tokens transfer will be occur.
     * @param operator The address which will receive the tokens.
     * @param ids The token id of tokens to be approved.
     */
    function isApprovedForTokens(
        address account,
        address operator,
        uint256[] memory ids
    ) public view returns (bool) {
        return nftAddress.isApprovedForTokens(account, operator, ids);
    }
}