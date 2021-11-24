// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ERC1155Signature.sol";
import "hardhat/console.sol";

contract ERC1155Implementation is
    AccessControlUpgradeable,
    ERC1155Upgradeable,
    ERC1155Signature
{
    struct Collection {
        string metaData;
        address creator;
        uint128 fee;
        uint256[] tokens;
    }

    bytes32 public constant SIGNER_ERC1155_ROLE =
        keccak256("SIGNER_ERC1155_ROLE");
    bytes32 public constant OWNER_ERC1155_ROLE =
        keccak256("OWNER_ERC1155_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    string public name;
    string public symbol;
    uint256 public lastId;
    uint128 constant hundredPercent = 100000; //100 *1000

    mapping(address => uint256[]) public creatorTokens;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenAmount;
    mapping(uint256 => uint128) public fees;
    mapping(uint256 => uint256) public tokenCollection;
    mapping(uint256 => mapping(address => uint256)) public locked;
    mapping(uint256 => Collection) private collections;
    uint256 public collectionCounter;
    event CreateCollection(
        uint256 collectionId,
        address creator,
        uint256[] tokens,
        uint128 fee,
        string metaData
    );
    event RemoveCollection(
        uint256 collectionId,
        address creator,
        uint256[] tokens
    );
    event Transfer(address from, address to, uint256[] ids, uint256[] amounts);
    event Fees(address indexed creator, uint256 id, uint128 fee);

    modifier onlyOwner() {
        require(
            hasRole(OWNER_ERC1155_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

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
        collectionCounter = 1;
        name = _name;
        symbol = _symbol;

        return true;
    }

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

    function setUri(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(0), _uint2str(id)));
    }

    function getCreatorTokens(address creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorTokens[creator];
    }

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
        require(fee <= hundredPercent / 2, "Royaties can not be bigger 50%");
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
        tokenAmount[id] = supply;

        if (id > lastId) {
            lastId = id;
        }

        _mint(msg.sender, id, supply, bytes(""));

        emit Fees(msg.sender, id, fee);
    }

    function burn(
        address owner,
        uint256 id,
        uint256 value
    ) external {
        require(
            owner == msg.sender || isApprovedForAll(owner, msg.sender),
            "Caller is not an owner or not approved"
        );
        tokenAmount[id] -= value;

        _burn(owner, id, value);
    }

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

    function isExistToken(uint256 tokenId) external view returns (bool) {
        return (creators[tokenId] != address(0));
    }

    function isCreator(address user, uint256 tokenId)
        external
        view
        returns (bool)
    {
        return creators[tokenId] == user;
    }

    function unlockTokens(
        address to,
        uint256 id,
        uint256 value
    ) external onlyMarketplace {
        require(locked[id][to] >= value, "Unlock amount exceeds locked tokens");
        locked[id][to] -= value;
    }

    function getLockedTokensValue(address owner, uint256 tokenId)
        public
        view
        returns (uint256 value)
    {
        return locked[tokenId][owner];
    }

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

    function getCollection(uint256 collectionId)
        external
        view
        returns (Collection memory)
    {
        return collections[collectionId];
    }

    function createCollection(
        uint256[] calldata tokens,
        uint128 fee,
        string calldata metaData,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(
            checkCollectionAction(msg.sender, tokens),
            "Impossible to create collection with this tokens"
        );
        require(fee <= hundredPercent / 2, "Royaties can not be bigger 50%");
        require(tokens.length > 1, "In collection should be more that 1 token");
        require(
            checkTokensCollection(tokens),
            "One of tokens is already part of another collection"
        );
        require(
            hasRole(
                SIGNER_ERC1155_ROLE,
                _getSigner(msg.sender, tokens, fee, metaData, v, r, s)
            ),
            "SignedAdmin should sign tokenId"
        );
        collections[collectionCounter] = Collection(
            metaData,
            msg.sender,
            fee,
            tokens
        );
        setCollectionToToken(collectionCounter, tokens);

        emit CreateCollection(
            collectionCounter,
            msg.sender,
            tokens,
            fee,
            metaData
        );
        collectionCounter += 1;
    }

    function removeCollection(uint256 collectionId) external {
        uint256[] memory tokens = collections[collectionId].tokens;

        require(
            checkCollectionAction(msg.sender, tokens),
            "Impossible to remove this collection"
        );
        require(tokens.length > 0, "Collection undefiend");
        setCollectionToToken(0, tokens);
        delete collections[collectionId];
        emit RemoveCollection(collectionId, msg.sender, tokens);
    }

    function checkTokensCollection(uint256[] memory tokens)
        internal
        returns (bool)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenCollection[tokens[i]] != 0) {
                return false;
            }
        }
        return true;
    }

    function checkCollectionAction(address user, uint256[] memory tokens)
        internal
        returns (bool)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (
                creators[tokens[i]] != user ||
                balanceOf(user, tokens[i]) != tokenAmount[tokens[i]] ||
                getLockedTokensValue(user, tokens[i]) != 0
            ) {
                return false;
            }
        }
        return true;
    }

    function setCollectionToToken(uint256 collectionId, uint256[] memory tokens)
        private
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenCollection[tokens[i]] = collectionId;
        }
    }

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