// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ERC1155Signature.sol";

/// @title ERC1155 Contract
/// @dev Simple 1155 contract with supporting Royalty standard
/// @dev Using ERC1155Signature for sign mint operation
contract ERC1155Implementation is
    AccessControlUpgradeable,
    ERC1155Upgradeable,
    ERC1155Signature
{
    bytes32 public constant SIGNER_ERC1155_ROLE =
        keccak256("SIGNER_ERC1155_ROLE");
    bytes32 public constant OWNER_ERC1155_ROLE =
        keccak256("OWNER_ERC1155_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    string public name;
    string public symbol;
    uint256 public lastId;
    uint128 constant hundredPercent = 100000;
    mapping(address => uint256[]) public creatorTokens;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokensAmount;
    mapping(uint256 => uint128) public fees;
    mapping(uint256 => mapping(address => uint256)) public locked;

    event Transfer(address from, address to, uint256[] ids, uint256[] amounts);
    event Fees(address indexed creator, uint256 id, uint128 fee);

    /// @dev Check if caller is contract owner

    modifier onlyOwner() {
        require(
            hasRole(OWNER_ERC1155_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    /// @dev Check if caller is marketplace contract

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

    /// @dev Check if this contract support interface
    /// @dev Need for checking by other contract if this contract support standard
    /// @param interfaceId interface identifier

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Sets main dependencies and constants
    /// @param _uri server url path for receive nft metadata
    /// @param _name 1155 nft name
    /// @param _symbol 1155 nft symbol
    /// @param _version version of contract
    /// @return true if initialization complete success

    function init(
        string memory _uri,
        string memory _name,
        string memory _symbol,
        string memory _version
    ) external returns (bool) {
        __ERC1155_init(_uri);
        __Signature_init(_name, _version);

        _setupRole(OWNER_ERC1155_ROLE, msg.sender);
        _setRoleAdmin(OWNER_ERC1155_ROLE, OWNER_ERC1155_ROLE);
        _setRoleAdmin(SIGNER_ERC1155_ROLE, OWNER_ERC1155_ROLE);
        _setRoleAdmin(MARKETPLACE_ROLE, OWNER_ERC1155_ROLE);
        name = _name;
        symbol = _symbol;

        return true;
    }

    /// @dev Get royalty info for token
    /// @param _tokenId id of token
    /// @param _salePrice sale price for token(s)
    /// @return receiver address of royalties receiver
    /// @return royaltyAmount amount of royalties that should paid to receiver

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        require(creators[_tokenId] != address(0), "Token does not exist");
        royaltyAmount =
            (_salePrice * uint256(fees[_tokenId])) /
            uint256(hundredPercent);
        receiver = creators[_tokenId];
    }

    /// @notice Get creators tokens
    /// @dev Return array of tokens by id
    /// @param creator address of creators
    /// @return tokens array of tokens, created by current address

    function getCreatorTokens(address creator)
        external
        view
        returns (uint256[] memory tokens)
    {
        tokens = creatorTokens[creator];
    }

    /// @dev Sets new path to metadata
    /// @param uri server url path for receive nft metadata

    function setUri(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    /// @dev Returns full path of metadata content by token id
    /// @param id token identifier
    /// @return full url path for receive metadata

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(0), _uint2str(id)));
    }

    /// @notice For minting any ERC1155 user should get sign by server
    /// @dev Mint ERC1155 token
    /// @param id token id, that received fromm server
    /// @param supply amount of tokens that should be mint
    /// @param fee fee, that creator want get after every sell
    /// @param signTime timestamp after which the signature is invalid
    /// @param v sign v value
    /// @param r sign r value
    /// @param s sign s value

    function mint(
        uint256 id,
        uint256 supply,
        uint128 fee,
        uint128 signTime,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= signTime, "Your signature has expired");
        require(creators[id] == address(0), "Token is already minted");
        require(supply != 0, "Supply should be positive");
        require(fee <= hundredPercent / 2, "Royalties can not be bigger 50%");
        require(
            hasRole(
                SIGNER_ERC1155_ROLE,
                _getSigner(id, supply, fee, signTime, msg.sender, v, r, s)
            ),
            "SignedAdmin should sign tokenId"
        );

        creatorTokens[msg.sender].push(id);
        creators[id] = msg.sender;
        fees[id] = fee;
        tokensAmount[id] = supply;

        if (id > lastId) {
            lastId = id;
        }

        _mint(msg.sender, id, supply, bytes(""));

        emit Fees(msg.sender, id, fee);
    }

    /// @notice Burns tokens by any token holder
    /// @dev User can burn tokens only if it is not locked
    /// @dev  Also, tokens may be burned by operator
    /// @param owner burnable  tokens owner
    /// @param id id of burnable token
    /// @param value amount of burnable tokens

    function burn(
        address owner,
        uint256 id,
        uint256 value
    ) external {
        require(
            owner == msg.sender || isApprovedForAll(owner, msg.sender),
            "Caller is not an owner or not approved"
        );
        require(
            balanceOf(owner, id) - getLockedTokensValue(owner, id) >= value,
            "Burn token value exceeds accessible token amount"
        );
        tokensAmount[id] -= value;

        _burn(owner, id, value);
    }

    /// @dev Lock tokens by marketplace contract
    /// @dev Locked tokens is not possible to transfer or do any actions with it
    /// @param to address of user whose tokens will lock
    /// @param id id of token that will lock
    /// @param value amount of tokens that will lock

    function lock(
        address to,
        uint256 id,
        uint256 value
    ) external onlyMarketplace {
        require(
            balanceOf(to, id) >= (value + locked[id][to]),
            "Lock amount exceeds balance"
        );
        locked[id][to] += value;
    }

    /// @dev Unlock tokens by marketplace contract
    /// @dev Call only if sell is complete or cancel
    /// @param to address of user whose tokens will unlock
    /// @param id id of token that will unlock
    /// @param value amount of tokens that will unlock

    function unlockTokens(
        address to,
        uint256 id,
        uint256 value
    ) external onlyMarketplace {
        require(locked[id][to] >= value, "Unlock amount exceeds locked tokens");
        locked[id][to] -= value;
    }

    /// @notice Return amount of tokens that locked ;
    /// @param owner address of token owner that validate
    /// @param tokenId id of token that validate
    /// @return value amount of locked tokens

    function getLockedTokensValue(address owner, uint256 tokenId)
        public
        view
        returns (uint256 value)
    {
        return locked[tokenId][owner];
    }

    /// @notice Return true if token exist;
    /// @param tokenId id of token
    /// @return true if token exist and false if token is not exist

    function isExistToken(uint256 tokenId) external view returns (bool) {
        return (creators[tokenId] != address(0));
    }

    /// @notice Return true if chosen user is token creator
    /// @param user address of user that will validate
    /// @param tokenId id of token that will validate
    /// @return true if user is token creator and false if user is not token creator

    function isCreator(address user, uint256 tokenId)
        external
        view
        returns (bool)
    {
        return creators[tokenId] == user;
    }

    /// @dev Call before token transfer. Check is tokens locked.
    /// @dev If tokens that should transfer locked, reject transaction
    /// @param operator address of function caller
    /// @param from address from which tokens will be transferred
    /// @param to address to which tokens will be transferred
    /// @param ids array of tokens ids
    /// @param amounts array of tokens amounts
    /// @param data additional data in bytes

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];

                uint256 fromBalance = balanceOf(from, id);
                uint256 fromLocked = locked[id][from];

                require(
                    fromLocked + amount <= fromBalance,
                    "Transfer amount exceeds balance or tokens locked"
                );
            }
            emit Transfer(from, to, ids, amounts);
        }
    }

    /// @dev Convert uint type variable to string
    /// @param i uint variable that should convert
    /// @return _uintAsString string contains uint value

    function _uint2str(uint256 i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (i == 0) {
            return "0";
        }
        uint256 j = i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory s = new bytes(len);
        uint256 k = len;
        while (i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(i - (i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            s[k] = b1;
            i /= 10;
        }
        return string(s);
    }
}