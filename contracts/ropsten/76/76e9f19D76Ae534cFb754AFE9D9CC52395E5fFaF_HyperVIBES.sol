//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// data stored for-each infused token
struct TokenData {
    uint256 dailyRate;
    uint256 balance;
    uint256 lastClaimAt;
}

// per-realm configuration
struct RealmConfig {
    IERC20 token;
    RealmConstraints constraints;
}

// modifyiable realm constraints
struct RealmConstraints {
    // token mining rate must be at least min
    uint256 minDailyRate;
    // token mining rate cannot exceed max
    uint256 maxDailyRate;
    // min amount allowed for a single infusion
    uint256 minInfusionAmount;
    // max amount allowed for a single infusion
    uint256 maxInfusionAmount;
    // token cannot have a total infused balance greater than `maxTokenBalance`
    uint256 maxTokenBalance;
    // if true, infuser must own the NFT being infused
    bool requireNftIsOwned;
    // if true, an nft can be infused multiple times
    bool allowMultiInfuse;
    // if true, any msg.sender may infuse if msg.sender = infuser. Delegated /
    // proxy infusions must always have the infuser on the whitelist
    bool allowPublicInfusion;
    // if true, any NFT from any collection may be infused. If false, contract
    // must be on the whitelist
    bool allowAllCollections;
}

// data provided when creating a realm
struct CreateRealmInput {
    string name;
    string description;
    RealmConfig config;
    address[] admins;
    address[] infusers;
    IERC721[] collections;
}

// data provided when modifying a realm
struct ModifyRealmInput {
    uint256 realmId;
    address[] adminsToAdd;
    address[] adminsToRemove;
    address[] infusersToAdd;
    address[] infusersToRemove;
    IERC721[] collectionsToAdd;
    IERC721[] collectionsToRemove;
}

// data provided when infusing an nft
struct InfuseInput {
    uint256 realmId;
    IERC721 collection;
    uint256 tokenId;
    address infuser;
    uint256 dailyRate;
    uint256 amount;
    string comment;
}

// data provided when claiming from an infused nft
struct ClaimInput {
    uint256 realmId;
    IERC721 collection;
    uint256 tokenId;
    uint256 amount;
}

contract HyperVIBES {
    // ---
    // storage
    // ---

    // realm ID -> realm data
    mapping(uint256 => RealmConfig) public realmConfig;

    // realm ID -> address -> (is admin flag)
    mapping(uint256 => mapping(address => bool)) public isAdmin;

    // realm ID -> address -> (is infuser flag)
    mapping(uint256 => mapping(address => bool)) public isInfuser;

    // realm ID -> erc721 -> (is allowed collection flag)
    mapping(uint256 => mapping(IERC721 => bool)) public isCollection;

    // realm ID -> nft -> token ID -> token data
    mapping(uint256 => mapping(IERC721 => mapping(uint256 => TokenData)))
        public tokenData;

    uint256 public nextRealmId = 1;

    // ---
    // events
    // ---

    event RealmCreated(uint256 indexed realmId, string name, string description);

    event AdminAdded(uint256 indexed realmId, address indexed admin);

    event AdminRemoved(uint256 indexed realmId, address indexed admin);

    event InfuserAdded(uint256 indexed realmId, address indexed infuser);

    event InfuserRemoved(uint256 indexed realmId, address indexed infuser);

    event CollectionAdded(uint256 indexed realmId, IERC721 indexed collection);

    event CollectionRemoved(uint256 indexed realmId, IERC721 indexed collection);

    event Infused(
        uint256 indexed realmId,
        IERC721 indexed collection,
        uint256 indexed tokenId,
        address infuser,
        uint256 amount,
        uint256 dailyRate,
        string comment
    );

    event Claimed(
        uint256 indexed realmId,
        IERC721 indexed collection,
        uint256 indexed tokenId,
        uint256 amount
    );

    // ---
    // admin mutations
    // ---

    // setup a new realm
    function createRealm(CreateRealmInput memory create) external {
        require(create.config.token != IERC20(address(0)), "invalid token");

        uint256 realmId = nextRealmId++;
        realmConfig[realmId] = create.config;

        emit RealmCreated(realmId, create.name, create.description);

        for (uint256 i = 0; i < create.admins.length; i++) {
            _addAdmin(realmId, create.admins[i]);
        }

        for (uint256 i = 0; i < create.infusers.length; i++) {
            _addInfuser(realmId, create.infusers[i]);
        }

        for (uint256 i = 0; i < create.collections.length; i++) {
            _addCollection(realmId, create.collections[i]);
        }
    }

    // update mutable configuration for a realm
    function modifyRealm(ModifyRealmInput memory input) public {
        require(isAdmin[input.realmId][msg.sender], "not realm admin");

        // adds

        for (uint256 i = 0; i < input.adminsToAdd.length; i++) {
            _addAdmin(input.realmId, input.adminsToAdd[i]);
        }

        for (uint256 i = 0; i < input.infusersToAdd.length; i++) {
            _addInfuser(input.realmId, input.infusersToAdd[i]);
        }

        for (uint256 i = 0; i < input.collectionsToAdd.length; i++) {
            _addCollection(input.realmId, input.collectionsToAdd[i]);
        }

        // removes

        for (uint256 i = 0; i < input.adminsToRemove.length; i++) {
            _removeAdmin(input.realmId, input.adminsToRemove[i]);
        }

        for (uint256 i = 0; i < input.infusersToRemove.length; i++) {
            _removeInfuser(input.realmId, input.infusersToRemove[i]);
        }

        for (uint256 i = 0; i < input.collectionsToRemove.length; i++) {
            _removeCollection(input.realmId, input.collectionsToRemove[i]);
        }
    }

    function _addAdmin(uint256 realmId, address admin) internal {
        require(admin != address(0), "invalid admin");
        isAdmin[realmId][admin] = true;
        emit AdminAdded(realmId, admin);
    }

    function _removeAdmin(uint256 realmId, address admin) internal {
        require(admin != address(0), "invalid admin");
        delete isAdmin[realmId][admin];
        emit AdminRemoved(realmId, admin);
    }

    function _addInfuser(uint256 realmId, address infuser) internal {
        require(infuser != address(0), "invalid infuser");
        isInfuser[realmId][infuser] = true;
        emit InfuserAdded(realmId, infuser);
    }

    function _removeInfuser(uint256 realmId, address infuser) internal {
        require(infuser != address(0), "invalid infuser");
        delete isInfuser[realmId][infuser];
        emit InfuserRemoved(realmId, infuser);
    }

    function _addCollection(uint256 realmId, IERC721 collection) internal {
        require(collection != IERC721(address(0)), "invalid collection");
        isCollection[realmId][collection] = true;
        emit CollectionAdded(realmId, collection);
    }

    function _removeCollection(uint256 realmId, IERC721 collection) internal {
        require(collection != IERC721(address(0)), "invalid collection");
        delete isCollection[realmId][collection];
        emit CollectionRemoved(realmId, collection);
    }

    // ---
    // infuser mutations
    // ---

    function infuse(InfuseInput memory input) external {
        require(_isTokenValid(input.collection, input.tokenId), "invalid token");

        TokenData storage data = tokenData[input.realmId][input.collection][input.tokenId];
        RealmConfig memory realm = realmConfig[input.realmId];

        // assert amount to be infused is within the min and max constraints
        require(input.amount >= realm.constraints.minInfusionAmount, "amount too low");
        require(input.amount <= realm.constraints.maxInfusionAmount, "amount too high");

        bool isPublicInfusion = msg.sender == input.infuser && realm.constraints.allowPublicInfusion;
        bool isOwnedByInfuser = input.collection.ownerOf(input.tokenId) == input.infuser;
        bool isOnInfuserWhitelist = isInfuser[input.realmId][msg.sender];
        bool isOnCollectionWhitelist = isCollection[input.realmId][input.collection];

        require(isOwnedByInfuser || !realm.constraints.requireNftIsOwned, "nft not owned by infuser");
        require(isOnInfuserWhitelist || isPublicInfusion, "invalid infuser");
        require(isOnCollectionWhitelist || realm.constraints.allowAllCollections, "invalid collection");

        // if already infused...
        if (data.lastClaimAt != 0) {
            require(data.dailyRate == input.dailyRate, "daily rate is immutable");
            require(realm.constraints.allowMultiInfuse, "multi infuse disabled");

            // intentionally ommitting checks to min/max daily rate -- its
            // possible realm configuration has changed since the initial
            // infusion, we don't want to prevent "topping off" the NFT if this
            // is the case
        } else {
            // else ensure daily rate is within min/max constraints
            require(input.dailyRate >= realm.constraints.minDailyRate, "daily rate too low");
            require(input.dailyRate <= realm.constraints.maxDailyRate, "daily rate too high");

            // initialize token storage
            data.dailyRate = input.dailyRate;
            data.lastClaimAt = block.timestamp;
        }

        // TODO: clamp amount based on balance and max balance

        // infuse
        // TODO: reentrancy risk!!!!!
        realm.token.transferFrom(msg.sender, address(this), input.amount);
        data.balance += input.amount;

        emit Infused(
            input.realmId,
            input.collection,
            input.tokenId,
            input.infuser,
            input.amount,
            input.dailyRate,
            input.comment
        );
    }

    // ---
    // claimer mutations
    // ---

    function claim(ClaimInput memory input) public {
        require(_isApprovedOrOwner(input.collection, input.tokenId, msg.sender), "not owner or approved");

        // compute how much we can claim, only pay attention to amount if its less
        // than available
        uint256 availableToClaim = _claimable(input.realmId, input.collection, input.tokenId);
        uint256 toClaim = input.amount < availableToClaim ? input.amount : availableToClaim;
        require(toClaim > 0, "nothing to claim");

        TokenData storage data = tokenData[input.realmId][input.collection][input.tokenId];

        // claim only as far up as we need to get our amount... basically "advances"
        // the lastClaim timestamp the exact amount needed to provide the amount
        // claim at = last + (to claim / rate) * 1 day, rewritten for div last
        uint256 claimAt = data.lastClaimAt + (toClaim * 1 days) / data.dailyRate;

        // update balances and execute ERC-20 transfer
        data.balance -= toClaim;
        data.lastClaimAt = claimAt;
        // TODO: reentrancy risk!!!!!
        realmConfig[input.realmId].token.transfer(msg.sender, toClaim);

        emit Claimed(input.realmId, input.collection, input.tokenId, toClaim);
    }

    // compute claimable tokens, reverts for invalid tokens
    function _claimable(
        uint256 realmId,
        IERC721 collection,
        uint256 tokenId
    ) internal view returns (uint256) {
        TokenData memory data = tokenData[realmId][collection][tokenId];
        require(data.lastClaimAt != 0, "token has not been infused");
        require(_isTokenValid(collection, tokenId), "invalid token");

        uint256 secondsToClaim = block.timestamp - data.lastClaimAt;
        uint256 toClaim = (secondsToClaim * data.dailyRate) / 1 days;

        // clamp to token balance
        return toClaim > data.balance ? data.balance : toClaim;
    }

    // ---
    // views
    // ---

    function name() external pure returns (string memory) {
        return "HyperVIBES";
    }

    // ---
    // utils
    // ---

    // returns true if a realm has been setup
    function _realmExists(uint256 realmId) internal view returns (bool) {
        return realmConfig[realmId].token != IERC20(address(0));
    }

    // returns true if token exists (and is not burnt)
    function _isTokenValid(IERC721 nft, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        try nft.ownerOf(tokenId) returns (address) {
            return true;
        } catch {
            return false;
        }
    }

    // returns true if operator can manage tokenId
    function _isApprovedOrOwner(
        IERC721 nft,
        uint256 tokenId,
        address operator
    ) internal view returns (bool) {
        address owner = nft.ownerOf(tokenId);
        return
            owner == operator ||
            nft.getApproved(tokenId) == operator ||
            nft.isApprovedForAll(owner, operator);
    }
}