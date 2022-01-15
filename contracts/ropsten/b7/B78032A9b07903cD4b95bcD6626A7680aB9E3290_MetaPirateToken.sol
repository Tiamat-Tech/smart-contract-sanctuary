// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./EnumerableUintToUintMap.sol";
import "./IMetaPirateToken.sol";

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract MetaPirateToken is AccessControlEnumerable, ERC20, IMetaPirateToken {
    using EnumerableUintToUintMap for EnumerableUintToUintMap.UintToUnitMap; 

    mapping(address => EnumerableUintToUintMap.UintToUnitMap) locked; // mapping(userAddress => mapping(releaseTime => amount))
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    address private poolAddress;
    

    constructor(address poolAddress_) ERC20("MetaPirate", "TMP") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(POOL_ROLE, poolAddress_);
        poolAddress = poolAddress_;
        uint256 preMint = 1000000000;
        _mint(poolAddress_, preMint * (10**uint256(18))); // 1000000000.mul(10**uint256(18));
    }

    bool inRelease;
    modifier lockRelease() {
        require(!inRelease, "release locked!");
        inRelease = true;
        _;
        inRelease = false;
    }

    bool inLock;
    modifier lockLock() {
        require(!inLock, "lock locked!");
        inLock = true;
        _;
        inLock = false;
    }

    function lock(
        address beneficiaryAddress_,
        uint256 releaseTime_,
        uint256 amount_
    ) public returns (bool) {
        require(
            hasRole(POOL_ROLE, _msgSender()),
            "MetaPirateToken: must have pool role to lock"
        );
        require(amount_ != 0, "MetaPirateToken: can not lock 0 amount");
        require(
            releaseTime_ > block.timestamp,
            "MetaPirateToken: release time is before current time"
        );
        require(
            !locked[beneficiaryAddress_].contains(releaseTime_), 
            "MetaPirateToken: tokens already locked"
        );
        locked[beneficiaryAddress_].set(releaseTime_, amount_);
        transfer(address(this), amount_);
        emit Locked(beneficiaryAddress_, releaseTime_, amount_);
        return true;
    }

    function increaseLockAmount(
        address beneficiaryAddress_,
        uint256 releaseTime_,
        uint256 amount_
    ) public returns (bool){
        require(
            hasRole(POOL_ROLE, _msgSender()),
            "MetaPirateToken: must have pool role to lock"
        );
        require(amount_ != 0, "MetaPirateToken: can not increase 0 amount");
        require(
            releaseTime_ > block.timestamp,
            "MetaPirateToken: release time is before current time"
        );
        require(
            locked[beneficiaryAddress_].contains(releaseTime_), 
            "MetaPirateToken: no tokens locked"
        );
        uint256 storedAmount = locked[beneficiaryAddress_].get(releaseTime_);
        uint256 finalAmount = storedAmount+amount_;
        locked[beneficiaryAddress_].set(releaseTime_, finalAmount);
        transfer(address(this), amount_);
        emit Locked(beneficiaryAddress_, releaseTime_, amount_);
        return true;
    }

    function release(address beneficiaryAddress_)
        public
        lockRelease
        returns (bool)
    {
        uint256 count = locked[beneficiaryAddress_].length();        
        uint256[] memory keys = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            (uint256 key, uint256 value) = locked[beneficiaryAddress_].at(i);            
            if (block.timestamp >= key) {
                keys[i] = key;
                _transfer(address(this), beneficiaryAddress_, value);
                emit Unlocked(beneficiaryAddress_, key, value);
            }
        }
        for (uint256 i = 0; i < count; i++) {
            if (keys[i] > 0) {
                locked[beneficiaryAddress_].remove(keys[i]);
            }            
        }

        return true;
    }

    function tokensLockedAtTime(
        address beneficiaryAddress_,
        uint256 releaseTime_
    ) public view virtual returns (uint256) {
        (bool success, uint256 value) = locked[beneficiaryAddress_].tryGet(
            releaseTime_
        );
        if (success) {
            return value;
        }
        return 0;
    }

    function balanceOfReleasable(address beneficiaryAddress_,uint256 timestamp_)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 amount = 0;
        uint256 count = locked[beneficiaryAddress_].length();
        for (uint256 i = 0; i < count; i++) {
            (uint256 key, uint256 value) = locked[beneficiaryAddress_].at(i);
            if (timestamp_ >= key) {
                amount += value;
            }
        }
        return amount;
    }

    function balanceOfUnReleasable(address beneficiaryAddress_,uint256 timestamp_)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 amount = 0;
        uint256 count = locked[beneficiaryAddress_].length();
        for (uint256 i = 0; i < count; i++) {
            (uint256 key, uint256 value) = locked[beneficiaryAddress_].at(i);
            if (timestamp_ < key) {
                amount += value;
            }
        }
        return amount;
    }

    function balanceOfUnReleased(address beneficiaryAddress_)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 amount = 0;
        uint256 count = locked[beneficiaryAddress_].length();
        for (uint256 i = 0; i < count; i++) {
            uint256 value = 0;
            (, value) = locked[beneficiaryAddress_].at(i);
            amount += value;
        }
        return amount;
    }

    function getLockedToken(address beneficiaryAddress_,uint256 timestamp_)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 amount = 0;
        uint256 count = locked[beneficiaryAddress_].length();
        for (uint256 i = 0; i < count; i++) {
            (uint256 key, uint256 value) = locked[beneficiaryAddress_].at(i);
            if (timestamp_ < key) {
                amount += value;
            }
        }
        return amount;
    }

    function getUnreleasedToken(address beneficiaryAddress_,uint256 timestamp_)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 amount = 0;
        uint256 count = locked[beneficiaryAddress_].length();
        for (uint256 i = 0; i < count; i++) {
            (uint256 key, uint256 value) = locked[beneficiaryAddress_].at(i);
            if (timestamp_ >= key) {
                amount += value;
            }
        }
        return amount;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IMetaPirateToken).interfaceId || super.supportsInterface(interfaceId);
    }
}